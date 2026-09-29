import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli_runner.dart';
import '../introspect/beak_introspection_emitter.dart';
import '../introspect/beak_live_schema.dart';
import '../introspect/beak_schema_introspection.dart';
import '../project/beak_emitters.dart';

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
/// Who owns the schema afterwards is the one decision the command asks for.
/// `--ownership adopt` (the default) makes the classes own their tables and
/// writes `lib/migrations/<stamp>_adopt_existing_schema.dart`, a baseline that
/// changes nothing on this database and builds the tables on an empty one.
/// `--ownership external` marks the classes `managesSchema: false` and writes
/// no migration, for a database another tool keeps; one that carries another
/// tool's migration history is treated that way unless told otherwise. A
/// Serverpod database is refused: its admin app belongs in the Serverpod
/// workspace.
///
/// ```console
/// $ beak introspect postgres://user:pass@localhost:5432/app --save-url
///   read 12 tables, 68 columns, 9 foreign keys
///   created lib/resources/customers/models/customer.dart
///   created lib/resources/orders/models/order.dart
///   created lib/migrations/20260928_101500_adopt_existing_schema.dart
///   ! orders.card_token looks like a secret and was omitted
///   created .env
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
      ..addOption(
        'ownership',
        help:
            'Who owns the schema from here on. Defaults to adopt, or to '
            'external when another tool\'s migration history is in the '
            'database.',
        allowed: [
          for (final ownership in BeakIntrospectionOwnership.values)
            ownership.name,
        ],
        allowedHelp: {
          BeakIntrospectionOwnership.adopt.name:
              'Beak owns the tables; a baseline migration records them.',
          BeakIntrospectionOwnership.external.name:
              'Another system owns them; Beak writes no migration.',
        },
      )
      ..addFlag(
        'save-url',
        help: 'Write DATABASE_URL=<url> into .env, where the server reads it.',
        negatable: false,
      )
      ..addFlag(
        'force',
        help:
            'Replace schema files that already exist and differ from what '
            'the database implies.',
        negatable: false,
      )
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

  /// The directory the baseline migration is written to.
  static const String migrationsRoot = 'lib/migrations';

  /// What the baseline migration's file name ends with.
  static const String baselineSuffix = '_adopt_existing_schema';

  /// The message when the database turns out to be Serverpod's.
  static const String serverpodRefusal =
      'This database belongs to a Serverpod server. Beak does not connect to '
      'it; add the admin app to your Serverpod workspace instead (see the '
      'Serverpod section of the docs).';

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

    if (tables.any((table) => table.name.startsWith(serverpodTablePrefix))) {
      environment.out.writeln(serverpodRefusal);
      return 1;
    }
    final BeakIntrospectionOwnership ownership = _ownershipFor(tables);

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
    final String normalizedOut = p.posix.normalize(out);
    final String schemaRoot = p.posix.relative(
      normalizedOut,
      from: migrationsRoot,
    );
    if (ownership == BeakIntrospectionOwnership.adopt &&
        normalizedOut != 'lib' &&
        !p.posix.isWithin('lib', normalizedOut)) {
      throw UsageException(
        '--out must be a directory under lib/, so the migration that adopts '
        'the schema can import the classes written there.',
        invocation,
      );
    }
    final layout = flatDirectory == null
        ? BeakIntrospectionLayout.featureFolders
        : BeakIntrospectionLayout.flat;
    final files = BeakIntrospectionEmitter.emitAll(
      selected,
      layout: layout,
      ownership: ownership,
    );
    if (files.isEmpty) {
      environment.out.writeln(
        '  nothing to write: every table was filtered out or is a pivot',
      );
      return 0;
    }

    final bool dryRun = argResults?['dry-run'] == true;
    final edited = <String>[
      if (argResults?['force'] != true)
        for (final file in files)
          if (_differsOnDisk('$out/${file.path}', file.contents))
            '$out/${file.path}',
    ];
    if (edited.isNotEmpty) {
      // The classes are the project's from the moment they are written, so
      // running this again must not take the edits back.
      for (final path in edited) {
        environment.out.writeln(
          '  $path already exists and differs from what the database implies',
        );
      }
      environment.out.writeln(
        '  nothing was written. Pass --force to replace ${edited.length == 1 ? 'it' : 'them'}, '
        'or leave the table out with --except.',
      );
      return 1;
    }
    for (final file in files) {
      if (_isOnDisk('$out/${file.path}', file.contents)) {
        environment.out.writeln('  unchanged $out/${file.path}');
        continue;
      }
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
    if (ownership == BeakIntrospectionOwnership.adopt) {
      _writeBaseline(selected, schemaRoot, layout, dryRun: dryRun);
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
    if (argResults?['save-url'] == true) {
      _saveUrl(rest.single, dryRun: dryRun);
    }
    _describeOwnership(ownership);
    if (!dryRun) {
      environment.out.writeln('\n  run `beak prepare` to wire them up');
    }
    return 0;
  }

  /// Who owns the schema: what was asked for, else what the database implies.
  ///
  /// Another tool's migration history means someone else keeps this schema.
  /// Adopting it anyway is possible, but it is a decision the user makes
  /// rather than a default that runs over their migration tool.
  BeakIntrospectionOwnership _ownershipFor(List<IntrospectedTable> tables) {
    if (argResults?.wasParsed('ownership') ?? false) {
      return BeakIntrospectionOwnership.values.byName(
        '${argResults?['ownership']}',
      );
    }
    final foreign = [
      for (final table in tables)
        if (foreignMigrationTables.contains(table.name)) table.name,
    ];
    if (foreign.isEmpty) {
      return BeakIntrospectionOwnership.adopt;
    }
    environment.out.writeln(
      '  note: this database has ${foreign.join(', ')}, so another tool '
      'migrates it. Beak reads it as external: the classes are marked '
      '`managesSchema: false` and no migration is written. Pass '
      '`--ownership adopt` to have Beak take the schema over instead.',
    );
    return BeakIntrospectionOwnership.external;
  }

  /// Writes the migration that adopts the schema, unless one is there.
  ///
  /// One baseline is all a project has: a second, written when the command is
  /// run again, would declare the same class and fail the build.
  void _writeBaseline(
    List<IntrospectedTable> tables,
    String schemaRoot,
    BeakIntrospectionLayout layout, {
    required bool dryRun,
  }) {
    if (_hasBaseline()) {
      environment.out.writeln(
        '  a migration under $migrationsRoot already adopts the schema; '
        'left as it was',
      );
      return;
    }
    final String name = '${_stampOf(environment.now())}$baselineSuffix';
    final String path = '$migrationsRoot/$name.dart';
    if (dryRun) {
      environment.out.writeln('  would create $path  (AdoptExistingSchema)');
      return;
    }
    environment.writeFile(
      path,
      BeakIntrospectionEmitter.emitBaseline(
        tables,
        migrationName: name,
        schemaRoot: schemaRoot,
        layout: layout,
      ),
    );
  }

  /// Whether the project already has a baseline migration, however named.
  bool _hasBaseline() {
    final directory = Directory(
      p.join(environment.rootDirectory.path, migrationsRoot),
    );
    if (!directory.existsSync()) {
      return false;
    }
    return directory.listSync().whereType<File>().any(
      (file) =>
          file.path.endsWith('$baselineSuffix.dart') ||
          file.readAsStringSync().contains('extends BeakBaselineMigration'),
    );
  }

  /// Upserts `DATABASE_URL=<[url]>` in the project's `.env`.
  ///
  /// The server reads it from there, and every other line stays as it was.
  void _saveUrl(String url, {required bool dryRun}) {
    if (dryRun) {
      environment.out.writeln('  would save DATABASE_URL to .env');
      return;
    }
    final file = File(p.join(environment.rootDirectory.path, '.env'));
    if (!file.existsSync()) {
      environment.writeFile('.env', 'DATABASE_URL=$url\n');
    } else {
      final String current = file.readAsStringSync();
      final String updated = _withDatabaseUrl(current, url);
      if (updated == current) {
        environment.out.writeln('  .env already has this DATABASE_URL');
      } else {
        file.writeAsStringSync(updated);
        environment.out.writeln('  updated .env');
      }
    }
    if (!_gitIgnoresEnv()) {
      environment.out.writeln(
        '  ! .env is not in .gitignore; the url may hold a password',
      );
    }
  }

  /// [env] with its `DATABASE_URL` set to [url], other lines untouched.
  static String _withDatabaseUrl(String env, String url) {
    final String eol = env.contains('\r\n') ? '\r\n' : '\n';
    final lines = env.split(eol);
    final assignment = RegExp(r'^\s*DATABASE_URL\s*=');
    final int at = lines.indexWhere(assignment.hasMatch);
    if (at >= 0) {
      lines[at] = 'DATABASE_URL=$url';
      return lines.join(eol);
    }
    // A file that ends in a newline splits into a trailing empty string,
    // which is where the new line goes; one that does not gets a break first.
    if (lines.last.isEmpty) {
      lines.removeLast();
    }
    return '${[...lines, 'DATABASE_URL=$url'].join(eol)}$eol';
  }

  /// Whether the project has a `.gitignore` that leaves out nothing about
  /// `.env`. A project without one is not a repository to warn about.
  bool _gitIgnoresEnv() {
    final file = File(p.join(environment.rootDirectory.path, '.gitignore'));
    if (!file.existsSync()) {
      return true;
    }
    return file.readAsLinesSync().any(
      (line) => const {'.env', '/.env', '.env*'}.contains(line.trim()),
    );
  }

  /// Whether the file at [path], relative to the project, exists with text
  /// other than [contents].
  bool _differsOnDisk(String path, String contents) {
    final file = File(p.join(environment.rootDirectory.path, path));
    return file.existsSync() &&
        file.readAsStringSync() != BeakEmitters.format(contents);
  }

  /// Whether the file at [path], relative to the project, already holds
  /// exactly [contents].
  bool _isOnDisk(String path, String contents) {
    final file = File(p.join(environment.rootDirectory.path, path));
    return file.existsSync() &&
        file.readAsStringSync() == BeakEmitters.format(contents);
  }

  /// Says what the chosen [ownership] means for `beak migrate`.
  void _describeOwnership(BeakIntrospectionOwnership ownership) {
    environment.out.writeln(switch (ownership) {
      BeakIntrospectionOwnership.adopt =>
        '  adopting   the migration records these tables as Beak\'s. On this '
            'database it changes nothing;\n'
            '             on an empty one it creates them.',
      BeakIntrospectionOwnership.external =>
        '  external   Beak does not migrate your tables. Run `beak migrate` '
            'once for its own\n'
            '             (`_beak_commit_receipts`, `_beak_outbox`, '
            '`worm_migrations`): saves fail without\n'
            '             them, and it touches none of yours.',
    });
  }

  /// `20260928_101500`, sortable and readable.
  static String _stampOf(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}${two(at.month)}${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}';
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
