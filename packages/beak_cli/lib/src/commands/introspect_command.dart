import 'package:args/command_runner.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

import '../cli_runner.dart';
import '../introspect/beak_introspection_emitter.dart';
import '../introspect/beak_live_schema.dart';
import '../introspect/beak_schema_introspection.dart';
import '../introspect/postgres_introspector.dart';

/// Opens a connection and returns a reader over it, plus how to close it.
///
/// Injected so the command can be tested without a database, and so the CLI
/// depends on a driver only where it actually connects.
typedef BeakDatabaseOpener =
    Future<(BeakSqlReader, Future<void> Function())> Function(Uri url);

/// Writes Beak schema classes for the tables an existing database already has.
///
/// The fastest way to see whether Beak fits is to point it at data you
/// already have. This reads `information_schema` and `pg_catalog` — types,
/// nullability, defaults, foreign keys, enum labels — and writes the same
/// annotated schema classes you would have written yourself, so the result is
/// an ordinary Beak project you can edit, not a generated artefact you cannot.
///
/// ```console
/// $ beak introspect postgres://user:pass@localhost:5432/app
///   read 12 tables, 68 columns, 9 foreign keys
///   created lib/models/customer.dart
///   created lib/models/order.dart
///   ! orders.card_token looks like a secret and was omitted
/// ```
final class IntrospectCommand extends Command<int> {
  /// Creates the command against [environment], connecting through [open].
  IntrospectCommand(this.environment, {BeakLiveSchemaReader? readSchema})
    : _readSchema = readSchema ?? beakReadLiveSchema {
    argParser
      ..addOption(
        'out',
        help: 'Directory the schema files are written to.',
        defaultsTo: 'lib/models',
      )
      ..addOption(
        'schema',
        help: 'Postgres schema to read.',
        defaultsTo: 'public',
      )
      ..addMultiOption('only', help: 'Only these tables.')
      ..addMultiOption('except', help: 'Every table but these.')
      ..addFlag(
        'dry-run',
        help: 'Report what would be written without writing it.',
        negatable: false,
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  final BeakLiveSchemaReader _readSchema;

  @override
  String get name => 'introspect';

  @override
  String get description =>
      'Write Beak models for the tables an existing database already has.';

  @override
  String get invocation => 'beak introspect <database-url>';

  @override
  Future<int> run() async {
    final List<String> rest = argResults?.rest ?? const [];
    if (rest.length != 1) {
      throw UsageException('Expected exactly one database URL.', invocation);
    }
    final Uri? url = Uri.tryParse(rest.single);
    if (url == null || url.scheme.isEmpty) {
      throw UsageException(
        '"${rest.single}" is not a database URL.',
        invocation,
      );
    }
    if (!beakCanReadSchema(url)) {
      environment.out.writeln(
        'Beak can introspect Postgres and SQLite; "${url.scheme}" is not '
        'supported yet.',
      );
      return 1;
    }

    final List<IntrospectedTable> tables = await _readSchema(
      beakResolvedDatabaseUrl(url, environment.rootDirectory),
      schema: switch (argResults?['schema']) {
        final String value => value,
        _ => 'public',
      },
    );

    final selected = _select(tables);
    environment.out.writeln(
      '  read ${selected.length} tables, '
      '${selected.fold(0, (sum, t) => sum + t.columns.length)} columns, '
      '${selected.fold(0, (sum, t) => sum + t.foreignKeys.length)} '
      'foreign keys',
    );

    final files = BeakIntrospectionEmitter.emitAll(selected);
    if (files.isEmpty) {
      environment.out.writeln(
        '  nothing to write — every table was filtered out or is a pivot',
      );
      return 0;
    }

    final String out = switch (argResults?['out']) {
      final String value => value,
      _ => 'lib/models',
    };
    final bool dryRun = argResults?['dry-run'] == true;
    for (final file in files) {
      if (dryRun) {
        environment.out.writeln(
          '  would create $out/${file.path}  '
          '(${file.className} over ${file.table})',
        );
      } else {
        environment.writeFile('$out/${file.path}', file.contents);
      }
      for (final note in file.notes) {
        environment.out.writeln('  ! $note');
      }
    }

    final skipped = [
      for (final table in tables)
        if (introspectionSkipTables.contains(table.name)) table.name,
    ];
    if (skipped.isNotEmpty) {
      environment.out.writeln(
        '  skipped ${skipped.join(', ')} (migration bookkeeping)',
      );
    }
    if (!dryRun) {
      environment.out.writeln('\n  run `beak prepare` to wire them up');
    }
    return 0;
  }

  /// The tables the `--only`/`--except` filters select.
  List<IntrospectedTable> _select(List<IntrospectedTable> tables) {
    final only = switch (argResults?['only']) {
      final List<String> values => values.toSet(),
      _ => const <String>{},
    };
    final except = switch (argResults?['except']) {
      final List<String> values => values.toSet(),
      _ => const <String>{},
    };
    return [
      for (final table in tables)
        if ((only.isEmpty || only.contains(table.name)) &&
            !except.contains(table.name) &&
            !introspectionSkipTables.contains(table.name))
          table,
    ];
  }
}

/// Whether Beak can introspect the database [url] names.
bool isIntrospectableUrl(Uri url) =>
    const {'postgres', 'postgresql'}.contains(url.scheme);

/// Connects to [url] and returns a reader over it, plus its closer.
///
/// The default [BeakDatabaseOpener]; tests pass their own so introspection
/// can be exercised against canned rows.
Future<(BeakSqlReader, Future<void> Function())> openPostgresConnection(
  Uri url,
) async {
  final String? userInfo = url.userInfo.isEmpty ? null : url.userInfo;
  final int separator = userInfo?.indexOf(':') ?? -1;
  final adapter = PostgresAdapter(
    pool: PostgresConnectionPool.fromConfig(
      ConnectionConfig(
        driver: 'postgres',
        host: url.host,
        port: url.hasPort ? url.port : 5432,
        database: url.pathSegments.isEmpty
            ? 'postgres'
            : url.pathSegments.first,
        username: userInfo == null
            ? null
            : Uri.decodeComponent(
                separator < 0 ? userInfo : userInfo.substring(0, separator),
              ),
        password: userInfo == null || separator < 0
            ? null
            : Uri.decodeComponent(userInfo.substring(separator + 1)),
        useSsl: url.queryParameters['sslmode'] == 'require',
      ),
    ),
  );
  await adapter.connect();
  return ((String sql) => adapter.rawQuery(sql, const []), adapter.disconnect);
}
