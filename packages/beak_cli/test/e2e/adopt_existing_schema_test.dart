@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// Adopting a database Beak did not create, the way a user does.
///
/// `beak introspect` reads a SQLite file that already holds tables and rows,
/// `beak prepare` derives the wiring, and `beak migrate` applies the baseline
/// it wrote. On the database the classes were read from the baseline must
/// change nothing and be recorded as applied; on an empty one it must build
/// every table, so a teammate's laptop or CI does not need a dump.
///
/// Runs on SQLite, so it needs nothing installed. It is tagged `e2e` for its
/// cost rather than its dependencies: a `flutter pub get` and a few `dart
/// run`s are too slow for the main gate.
void main() {
  test(
    'an existing database is adopted untouched, and an empty one is built',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final workspace = Directory.systemTemp.createTempSync('beak_adopt_');
      addTearDown(() => workspace.deleteSync(recursive: true));
      final project = Directory('${workspace.path}/shop')..createSync();

      final legacy = '${workspace.path}/legacy.db';
      _createLegacyDatabase(legacy);
      final Map<String, List<String>> before = _columnsOf(legacy);

      File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: shop
publish_to: none
environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'
dependencies:
  beak:
    path: ${repoRoot.path}/packages/beak
  flutter:
    sdk: flutter
''');
      final environment = BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: project,
        now: () => DateTime.utc(2026, 9, 28, 10, 15),
        probe: (host, port) async => false,
      );

      // 1. Read the database that is already there, and remember where it is.
      expect(
        await createBeakRunner(
          environment,
        ).run(['introspect', 'sqlite:$legacy', '--save-url']),
        0,
      );
      const baseline =
          'lib/migrations/20260928_101500_adopt_existing_schema.dart';
      expect(File('${project.path}/$baseline').existsSync(), isTrue);
      expect(
        File('${project.path}/.env').readAsStringSync(),
        'DATABASE_URL=sqlite:$legacy\n',
      );

      // 2. Derive the wiring. The baseline covers every table, so prepare has
      // no create migration to write.
      final BeakPrepareResult prepared = runPrepare(environment);
      expect(
        prepared.isSuccess,
        isTrue,
        reason: '${prepared.discovery.issues}',
      );
      expect(
        Directory(
          '${project.path}/lib/migrations',
        ).listSync().map((entity) => entity.uri.pathSegments.last).toList(),
        ['20260928_101500_adopt_existing_schema.dart'],
      );
      await _run(project, ['flutter', 'pub', 'get']);

      // 3. Migrate the database it was read from. The URL comes from .env.
      final ProcessResult migrated = await _run(project, [
        'dart',
        'run',
        'bin/migrate.dart',
        'migrate',
      ]);
      expect(migrated.stdout, contains('adopt_existing_schema'));

      final Map<String, List<String>> after = _columnsOf(legacy);
      for (final MapEntry(key: table, value: columns) in before.entries) {
        expect(after[table], columns, reason: '$table was altered');
      }
      expect(_rowCount(legacy, 'products'), 2);
      expect(_rowCount(legacy, 'product_tag'), 1);
      expect(
        _applied(legacy),
        contains('20260928_101500_adopt_existing_schema'),
        reason: 'the baseline is recorded as applied',
      );

      // 4. Migrate an empty database: the baseline builds everything.
      final fresh = '${workspace.path}/fresh.db';
      await _run(
        project,
        ['dart', 'run', 'bin/migrate.dart', 'migrate'],
        environment: {'DATABASE_URL': 'sqlite:$fresh'},
      );

      final Map<String, List<String>> built = _columnsOf(fresh);
      for (final MapEntry(key: table, value: columns) in before.entries) {
        expect(built[table], isNotNull, reason: '$table was not created');
        expect(
          built[table],
          containsAll(columns),
          reason: '$table came back with different columns',
        );
      }
      expect(_rowCount(fresh, 'products'), 0);
      expect(
        _applied(fresh),
        contains('20260928_101500_adopt_existing_schema'),
      );

      // 5. Going back is refused, and leaves the tables alone.
      final ProcessResult rolledBack = await Process.run(
        'dart',
        ['run', 'bin/migrate.dart', 'migrate:rollback'],
        workingDirectory: project.path,
        environment: {'DATABASE_URL': 'sqlite:$fresh'},
      );
      expect(rolledBack.exitCode, isNot(0));
      expect(
        '${rolledBack.stdout}${rolledBack.stderr}',
        contains('cannot be rolled back'),
      );
      expect(_columnsOf(fresh).keys, containsAll(before.keys));

      // 6. And the project reads as healthy.
      final checks = await diagnose(
        environment,
        readSchema: (url, {String schema = 'public'}) async => [],
      );
      expect(
        checks.where((check) => check.status == BeakCheckStatus.fail),
        isEmpty,
        reason: checks.map((check) => check.label).join('\n'),
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

/// A database with data in it and a column no schema class will ever hold.
void _createLegacyDatabase(String path) {
  final Database db = sqlite3.open(path);
  try {
    db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY NOT NULL,
  name VARCHAR(120) NOT NULL,
  legacy_code TEXT
);
CREATE TABLE tags (
  id TEXT PRIMARY KEY NOT NULL,
  name VARCHAR(60) NOT NULL
);
CREATE TABLE products (
  id TEXT PRIMARY KEY NOT NULL,
  name VARCHAR(255) NOT NULL,
  category_id TEXT REFERENCES categories (id) ON DELETE SET NULL
);
CREATE TABLE product_tag (
  product_id TEXT NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE
);
INSERT INTO categories VALUES ('c1', 'Coffee', 'OLD-1');
INSERT INTO tags VALUES ('t1', 'Fresh');
INSERT INTO products VALUES ('p1', 'Espresso Beans', 'c1');
INSERT INTO products VALUES ('p2', 'Filter Beans', 'c1');
INSERT INTO product_tag VALUES ('p1', 't1');
''');
  } finally {
    db.close();
  }
}

/// The application tables of [path], each with its columns in order.
Map<String, List<String>> _columnsOf(String path) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final tables = [
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'worm_%' "
        "AND name NOT LIKE '\\_beak\\_%' ESCAPE '\\' ORDER BY name",
      ))
        row['name'] as String,
    ];
    return {
      for (final table in tables)
        table: [
          for (final column in db.select('PRAGMA table_info("$table")'))
            column['name'] as String,
        ],
    };
  } finally {
    db.close();
  }
}

int _rowCount(String path, String table) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return db.select('SELECT COUNT(*) AS n FROM "$table"').single['n'] as int;
  } finally {
    db.close();
  }
}

/// The names worm has recorded as applied in [path].
List<String> _applied(String path) {
  final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return [
      for (final row in db.select('SELECT name FROM worm_migrations'))
        row['name'] as String,
    ];
  } finally {
    db.close();
  }
}

/// Runs [command] in [project], failing the test with its output.
Future<ProcessResult> _run(
  Directory project,
  List<String> command, {
  Map<String, String> environment = const {},
}) async {
  final ProcessResult result = await Process.run(
    command.first,
    command.skip(1).toList(),
    workingDirectory: project.path,
    environment: environment,
  );
  expect(
    result.exitCode,
    0,
    reason: '${command.join(' ')} failed:\n${result.stdout}\n${result.stderr}',
  );
  return result;
}
