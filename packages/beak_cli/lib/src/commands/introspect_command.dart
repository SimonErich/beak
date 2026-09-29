import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../introspect/beak_introspection_emitter.dart';
import '../introspect/beak_live_schema.dart';
import '../introspect/beak_schema_introspection.dart';

/// Writes Beak schema classes for the tables an existing database already has.
///
/// The fastest way to see whether Beak fits is to point it at data you
/// already have. This reads `information_schema` and `pg_catalog` — types,
/// nullability, defaults, foreign keys, enum labels — and writes the same
/// annotated schema classes you would have written yourself, so the result is
/// an ordinary Beak project you can edit, not a generated artefact you cannot.
/// Each table gets a feature folder, `lib/resources/<table>/models/`, the
/// layout `beak make:resource` writes; `--out <dir>` writes every file flat
/// into one directory instead.
///
/// ```console
/// $ beak introspect postgres://user:pass@localhost:5432/app
///   read 12 tables, 68 columns, 9 foreign keys
///   created lib/resources/customers/models/customer.dart
///   created lib/resources/orders/models/order.dart
///   ! orders.card_token looks like a secret and was omitted
/// ```
final class IntrospectCommand extends Command<int> {
  /// Creates the command against [environment], reading the live schema
  /// through [readSchema] (a real connection unless a test supplies one).
  IntrospectCommand(this.environment, {BeakLiveSchemaReader? readSchema})
    : _readSchema = readSchema ?? beakReadLiveSchema {
    argParser
      ..addOption(
        'out',
        help:
            'Write every schema file flat into this directory, instead of '
            'into lib/resources/<table>/models/ for each table.',
        valueHelp: 'dir',
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

  /// The directory each table's feature folder goes under.
  static const String featureFoldersRoot = 'lib/resources';

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

    final String? flatDirectory = switch (argResults?['out']) {
      final String value => value,
      _ => null,
    };
    final String out = flatDirectory ?? featureFoldersRoot;
    final files = BeakIntrospectionEmitter.emitAll(
      selected,
      layout: flatDirectory == null
          ? BeakIntrospectionLayout.featureFolders
          : BeakIntrospectionLayout.flat,
    );
    if (files.isEmpty) {
      environment.out.writeln(
        '  nothing to write — every table was filtered out or is a pivot',
      );
      return 0;
    }

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
