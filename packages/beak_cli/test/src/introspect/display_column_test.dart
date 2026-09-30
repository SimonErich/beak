import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import '../../support/fake_database.dart';

/// The schema class emitted for [table], by table name.
Map<String, String> emitted(List<IntrospectedTable> tables) => {
  for (final file in BeakIntrospectionEmitter.emitAll(tables))
    file.table: file.contents,
};

/// The line after `@Display()` in [source], which is the column it marks, or
/// `null` when nothing is marked.
String? displayed(String source) {
  final List<String> lines = source.split('\n');
  final int marker = lines.indexWhere((line) => line.contains('@Display()'));
  if (marker < 0) {
    return null;
  }
  return lines
      .skip(marker + 1)
      .firstWhere((line) => line.contains(' late final '))
      .trim();
}

/// Reads [database] the way `beak introspect sqlite:...` does.
Future<List<IntrospectedTable>> readSqlite(Database database) =>
    SqliteIntrospector((sql) async {
      final ResultSet rows = database.select(sql);
      return [
        for (final row in rows) <String, Object?>{...row},
      ];
    }).read();

Future<Map<String, String>> emittedFromPostgres(
  List<Map<String, Object?>> columns,
) async => emitted(
  await PostgresIntrospector(
    FakeDatabase(
      columns: columns,
      primaryKeys: [
        for (final table in {for (final c in columns) c['table_name']})
          {'table_name': table, 'column_name': 'id'},
      ],
    ).query,
  ).read(),
);

void main() {
  group('on Postgres', () {
    test('a text column named name is the display column', () async {
      final files = await emittedFromPostgres([
        column('places', 'id', 'uuid', nullable: false),
        column('places', 'name', 'text', nullable: false),
        column('places', 'notes', 'text'),
      ]);

      expect(displayed(files['places']!), 'late final BeakText name;');
    });

    test('a varchar column named name still is', () async {
      final files = await emittedFromPostgres([
        column('places', 'id', 'uuid', nullable: false),
        column(
          'places',
          'name',
          'character varying',
          nullable: false,
          maxLength: 80,
        ),
      ]);

      expect(displayed(files['places']!), 'late final String name;');
    });

    test('prefers name, title, label, email, code in that order', () async {
      const order = ['name', 'title', 'label', 'email', 'code'];
      for (var first = 0; first < order.length; first++) {
        // Every column from `first` on exists, declared in reverse so column
        // order cannot be what decides.
        final files = await emittedFromPostgres([
          column('things', 'id', 'uuid', nullable: false),
          for (final name in order.skip(first).toList().reversed)
            column('things', name, 'text'),
        ]);

        expect(
          displayed(files['things']!),
          contains(' ${order[first]};'),
          reason: 'with ${order.skip(first).join(', ')} present',
        );
      }
    });

    test('marks exactly one column', () async {
      final files = await emittedFromPostgres([
        column('things', 'id', 'uuid', nullable: false),
        column('things', 'title', 'text'),
        column('things', 'name', 'text'),
      ]);

      expect('@Display()'.allMatches(files['things']!), hasLength(1));
    });

    test('a table with no such column has no display column', () async {
      final files = await emittedFromPostgres([
        column('things', 'id', 'uuid', nullable: false),
        column('things', 'notes', 'text'),
        column('things', 'quantity', 'integer'),
      ]);

      expect(files['things'], isNot(contains('@Display()')));
    });

    test('a column named name that is not text is not one', () async {
      final files = await emittedFromPostgres([
        column('things', 'id', 'uuid', nullable: false),
        column('things', 'name', 'integer'),
      ]);

      expect(files['things'], isNot(contains('@Display()')));
    });

    test('a text display column is searchable', () async {
      final files = await emittedFromPostgres([
        column('places', 'id', 'uuid', nullable: false),
        column('places', 'name', 'text', nullable: false),
      ]);

      expect(files['places'], contains('searchable: true'));
    });
  });

  group('on SQLite', () {
    late Database database;

    setUp(() => database = sqlite3.openInMemory());
    tearDown(() => database.close());

    test('a TEXT column named name is the display column', () async {
      database.execute(
        'CREATE TABLE customers ('
        'id INTEGER PRIMARY KEY, name TEXT NOT NULL, notes TEXT)',
      );

      final files = emitted(await readSqlite(database));

      expect(displayed(files['customers']!), 'late final BeakText name;');
    });

    test('a VARCHAR column named title is', () async {
      database.execute(
        'CREATE TABLE posts (id INTEGER PRIMARY KEY, body TEXT, '
        'title VARCHAR(120) NOT NULL)',
      );

      final files = emitted(await readSqlite(database));

      expect(displayed(files['posts']!), 'late final String title;');
    });

    test('name beats title whichever is declared first', () async {
      database.execute(
        'CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT, name TEXT)',
      );

      final files = emitted(await readSqlite(database));

      expect(displayed(files['posts']!), contains(' name;'));
    });

    test('falls back through label, email and code', () async {
      database.execute(
        'CREATE TABLE contacts (id INTEGER PRIMARY KEY, code TEXT, '
        'email TEXT, label TEXT)',
      );
      database.execute(
        'CREATE TABLE coupons (id INTEGER PRIMARY KEY, code TEXT, note TEXT)',
      );

      final files = emitted(await readSqlite(database));

      expect(displayed(files['contacts']!), contains(' label;'));
      expect(displayed(files['coupons']!), contains(' code;'));
    });

    test('a table without a candidate has none', () async {
      database.execute(
        'CREATE TABLE readings (id INTEGER PRIMARY KEY, value REAL, note TEXT)',
      );

      final files = emitted(await readSqlite(database));

      expect(files['readings'], isNot(contains('@Display()')));
    });
  });
}
