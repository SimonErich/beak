@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

/// The round trip: a database Beak did not create, read back out of it, and
/// rebuilt somewhere else.
///
/// `beak introspect` writes schema classes from a live schema, `beak prepare`
/// derives migrations from those classes, and applying them to an empty
/// database must produce the schema we started from. Every step in that chain
/// is lossy if any one of them drops something, and the loss is invisible
/// until a query fails months later: a `VARCHAR(120)` that came back as
/// `VARCHAR(255)`, an index that was never created, a foreign key that lost
/// its delete rule.
///
/// So this asserts the two schemas column for column, index for index, and
/// constraint for constraint. It is tagged `e2e` because it needs a real
/// Postgres: no other database has enough of a catalog to compare against.
void main() {
  final Uri base = Uri.parse(
    Platform.environment['DATABASE_URL'] ??
        'postgres://beak:beak@localhost:25432/beak',
  );

  /// Two dedicated databases: the original, and the one rebuilt from what was
  /// read out of it. Derived, never taken from the environment, so this
  /// suite's drops can only ever land in a `*_round_trip*` database.
  Uri databaseFor(String suffix) =>
      base.replace(pathSegments: ['beak_round_trip_$suffix']);

  late DatabaseAdapter origin;
  late DatabaseAdapter rebuilt;

  setUpAll(() async {
    if (!await _reachable(base)) {
      throw StateError(
        'Postgres is unreachable — start it with `melos run up`.',
      );
    }
    for (final suffix in const ['origin', 'rebuilt']) {
      await _createDatabase(base, databaseFor(suffix).pathSegments.first);
    }
    origin = await _connect(databaseFor('origin'));
    rebuilt = await _connect(databaseFor('rebuilt'));
    await _dropEverything(origin);
    await _dropEverything(rebuilt);
    await _createOriginSchema(origin);
  });

  tearDownAll(() async {
    await origin.disconnect();
    await rebuilt.disconnect();
  });

  test('a schema survives introspect, generate, and migrate', () async {
    final project = Directory.systemTemp.createTempSync('beak_round_trip_');
    addTearDown(() => project.deleteSync(recursive: true));
    final Directory repoRoot = Directory.current.parent.parent;
    // A real project: the generated entrypoints import `package:shop`, and
    // the models import `package:beak`.
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
      now: () => DateTime.utc(2026, 7, 28, 12),
      probe: (host, port) async => false,
    );

    // 1. Read the schema out of the database that already had it.
    final int? introspected = await createBeakRunner(
      environment,
    ).run(['introspect', databaseFor('origin').toString()]);
    expect(introspected, 0);
    expect(
      Directory(
        '${project.path}/lib/models',
      ).listSync().map((entity) => entity.uri.pathSegments.last),
      containsAll(<String>['category.dart', 'product.dart']),
    );

    // 2. Adopt the tables. Introspection says another system owns their
    // schema, which is true of the database they were read from; the
    // rebuild is Beak's to create, so the classes take ownership first.
    for (final file in Directory(
      '${project.path}/lib/models',
    ).listSync().whereType<File>()) {
      // However the formatter laid the annotation out.
      file.writeAsStringSync(
        file.readAsStringSync().replaceAll(
          RegExp(r'managesSchema: false,?\s*'),
          '',
        ),
      );
    }

    // 3. Derive everything else from what was written, migrations included.
    final BeakPrepareResult prepared = runPrepare(environment);
    expect(prepared.isSuccess, isTrue, reason: '${prepared.discovery.issues}');

    // 4. Apply them to a database that has nothing.
    final ProcessResult pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: project.path);
    expect(pubGet.exitCode, 0, reason: '${pubGet.stdout}\n${pubGet.stderr}');
    await _runMigrations(project, databaseFor('rebuilt'));

    // 5. The two schemas must agree, in the detail that a query depends on.
    final Map<String, List<_Column>> before = await _columns(origin);
    final Map<String, List<_Column>> after = await _columns(rebuilt);

    expect(after.keys, containsAll(before.keys));
    for (final table in before.keys) {
      expect(
        after[table],
        before[table],
        reason: 'the $table table came back different',
      );
    }

    expect(
      await _indexedColumns(rebuilt),
      containsAll(await _indexedColumns(origin)),
    );
    expect(
      await _foreignKeys(rebuilt),
      containsAll(await _foreignKeys(origin)),
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}

/// One column, in the detail a rebuilt schema has to reproduce.
final class _Column {
  const _Column({
    required this.name,
    required this.type,
    required this.nullable,
    required this.length,
    required this.precision,
    required this.scale,
  });

  final String name;
  final String type;
  final bool nullable;
  final int? length;
  final int? precision;
  final int? scale;

  @override
  bool operator ==(Object other) =>
      other is _Column &&
      other.name == name &&
      other.type == type &&
      other.nullable == nullable &&
      other.length == length &&
      other.precision == precision &&
      other.scale == scale;

  @override
  int get hashCode =>
      Object.hash(name, type, nullable, length, precision, scale);

  @override
  String toString() =>
      '$name $type${length == null ? '' : '($length)'}'
      '${precision == null ? '' : '($precision,$scale)'}'
      '${nullable ? '' : ' NOT NULL'}';
}

/// The schema this round trip starts from.
///
/// Chosen for what it can lose: a bounded `VARCHAR`, a `NUMERIC` whose width
/// is deliberately NOT the default `(10, 2)` a generated migration falls back
/// to, a nullable and a non-nullable column, an index that is not a key, and
/// a foreign key with a delete rule that is not the default. Every one of
/// those is a value the trip has to carry rather than reconstruct, and a
/// fixture made of defaults would pass while losing them all.
Future<void> _createOriginSchema(DatabaseAdapter adapter) async {
  await adapter.rawQuery('''
CREATE TABLE categories (
  id UUID NOT NULL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  blurb TEXT
)''', const <Object?>[]);
  await adapter.rawQuery('''
CREATE TABLE products (
  id UUID NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  sku VARCHAR(40) NOT NULL,
  price NUMERIC(12, 4) NOT NULL,
  stock INTEGER,
  category_id UUID REFERENCES categories (id) ON DELETE SET NULL
)''', const <Object?>[]);
  await adapter.rawQuery(
    'CREATE INDEX products_name_idx ON products (name)',
    const <Object?>[],
  );
  await adapter.rawQuery(
    'CREATE UNIQUE INDEX products_sku_idx ON products (sku)',
    const <Object?>[],
  );
}

/// Every table's columns, keyed by table.
Future<Map<String, List<_Column>>> _columns(DatabaseAdapter adapter) async {
  final rows = await adapter.rawQuery('''
SELECT c.table_name, c.column_name, c.data_type, c.is_nullable,
       c.character_maximum_length, c.numeric_precision, c.numeric_scale
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_name = c.table_name AND t.table_schema = c.table_schema
WHERE c.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
  AND c.table_name <> 'migrations'
ORDER BY c.table_name, c.column_name''', const <Object?>[]);

  final columns = <String, List<_Column>>{};
  for (final row in rows) {
    final String table = '${row['table_name']}';
    columns
        .putIfAbsent(table, () => <_Column>[])
        .add(
          _Column(
            name: '${row['column_name']}',
            type: '${row['data_type']}',
            nullable: row['is_nullable'] == 'YES',
            length: _asInt(row['character_maximum_length']),
            precision: _asInt(row['numeric_precision']),
            scale: _asInt(row['numeric_scale']),
          ),
        );
  }
  return columns;
}

/// Every indexed `table.column`, however the index was created.
///
/// Compared as a set rather than by index name: a rebuilt schema is free to
/// name its indexes differently, and does.
Future<Set<String>> _indexedColumns(DatabaseAdapter adapter) async {
  final rows = await adapter.rawQuery(
    '''
SELECT t.relname AS table_name, a.attname AS column_name, i.indisunique
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_class t ON t.oid = i.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (i.indkey)
WHERE n.nspname = 'public' AND t.relname <> 'migrations' ''',
    const <Object?>[],
  );
  return {
    for (final row in rows)
      '${row['table_name']}.${row['column_name']}'
          '${row['indisunique'] == true ? ' unique' : ''}',
  };
}

/// Every foreign key as `table.column -> target (rule)`.
Future<Set<String>> _foreignKeys(DatabaseAdapter adapter) async {
  final rows = await adapter.rawQuery('''
SELECT src.relname AS table_name, sa.attname AS column_name,
       tgt.relname AS target_table, c.confdeltype
FROM pg_constraint c
JOIN pg_class src ON src.oid = c.conrelid
JOIN pg_class tgt ON tgt.oid = c.confrelid
JOIN pg_namespace n ON n.oid = src.relnamespace
JOIN pg_attribute sa ON sa.attrelid = src.oid AND sa.attnum = ANY (c.conkey)
WHERE c.contype = 'f' AND n.nspname = 'public' ''', const <Object?>[]);
  return {
    for (final row in rows)
      '${row['table_name']}.${row['column_name']} -> '
          '${row['target_table']} (${row['confdeltype']})',
  };
}

int? _asInt(Object? value) => switch (value) {
  final int number => number,
  final String text => int.tryParse(text),
  _ => null,
};

/// Runs the project's generated migrations against [databaseUrl].
Future<void> _runMigrations(Directory project, Uri databaseUrl) async {
  final ProcessResult result = await Process.run(
    'dart',
    ['run', 'bin/migrate.dart', 'migrate'],
    workingDirectory: project.path,
    environment: {'DATABASE_URL': databaseUrl.toString()},
  );
  expect(
    result.exitCode,
    0,
    reason: 'migrate failed:\n${result.stdout}\n${result.stderr}',
  );
}

Future<bool> _reachable(Uri url) async {
  try {
    final socket = await Socket.connect(
      url.host,
      url.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

/// Creates [name] if it is not there. `CREATE DATABASE` has no
/// `IF NOT EXISTS`, so probe first.
Future<void> _createDatabase(Uri base, String name) async {
  final maintenance = _adapterFor(
    base.replace(pathSegments: const ['postgres']),
  );
  await maintenance.connect();
  try {
    final rows = await maintenance.rawQuery(
      r'SELECT 1 FROM pg_database WHERE datname = $1',
      [name],
    );
    if (rows.isEmpty) {
      await maintenance.rawQuery('CREATE DATABASE "$name"', const <Object?>[]);
    }
  } finally {
    await maintenance.disconnect();
  }
}

Future<DatabaseAdapter> _connect(Uri url) async {
  final adapter = _adapterFor(url);
  await adapter.connect();
  return adapter;
}

/// A Postgres adapter over [url].
///
/// Built here rather than borrowed from `beak_backend`, which `beak_cli`
/// deliberately does not depend on: the CLI reads source, it does not serve.
PostgresAdapter _adapterFor(Uri url) {
  final String userInfo = url.userInfo;
  final int separator = userInfo.indexOf(':');
  return PostgresAdapter(
    pool: PostgresConnectionPool.fromConfig(
      ConnectionConfig(
        driver: 'postgres',
        host: url.host,
        port: url.hasPort ? url.port : 5432,
        database: url.pathSegments.isEmpty
            ? 'postgres'
            : url.pathSegments.first,
        username: separator < 0 ? null : userInfo.substring(0, separator),
        password: separator < 0 ? null : userInfo.substring(separator + 1),
      ),
    ),
  );
}

/// Empties a round-trip database so a run starts from nothing.
///
/// One statement per call: a prepared statement carries exactly one.
Future<void> _dropEverything(DatabaseAdapter adapter) async {
  await adapter.rawQuery('DROP SCHEMA public CASCADE', const <Object?>[]);
  await adapter.rawQuery('CREATE SCHEMA public', const <Object?>[]);
}
