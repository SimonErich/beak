import 'package:beak_cli/beak_cli.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Reads [database] the way the introspector does in production.
Future<List<IntrospectedTable>> introspect(Database database) =>
    SqliteIntrospector((sql) async {
      final ResultSet rows = database.select(sql);
      return [
        for (final row in rows) <String, Object?>{...row},
      ];
    }).read();

/// The table named [name] in [tables].
IntrospectedTable tableNamed(List<IntrospectedTable> tables, String name) =>
    tables.firstWhere((table) => table.name == name);

/// The column named [name] of [table].
IntrospectedColumn columnNamed(IntrospectedTable table, String name) =>
    table.columns.firstWhere((column) => column.name == name);

void main() {
  late Database database;

  setUp(() {
    database = sqlite3.openInMemory();
  });

  tearDown(() => database.dispose());

  group('tables', () {
    test('are read, and SQLite\'s own bookkeeping is not', () {
      database
        ..execute('CREATE TABLE products (id TEXT PRIMARY KEY)')
        ..execute('CREATE TABLE categories (id TEXT PRIMARY KEY)')
        // An AUTOINCREMENT column makes SQLite create `sqlite_sequence`,
        // which is not a table anyone modelled.
        ..execute(
          'CREATE TABLE counters (id INTEGER PRIMARY KEY AUTOINCREMENT)',
        )
        ..execute('INSERT INTO counters DEFAULT VALUES');

      expect(
        introspect(database),
        completion(
          isA<List<IntrospectedTable>>().having(
            (tables) => tables.map((table) => table.name),
            'names',
            <String>['categories', 'counters', 'products'],
          ),
        ),
      );
    });

    test('a view is not a table', () async {
      database
        ..execute('CREATE TABLE products (id TEXT PRIMARY KEY, price REAL)')
        ..execute(
          'CREATE VIEW cheap AS SELECT * FROM products WHERE price < 5',
        );

      final tables = await introspect(database);
      expect(tables.map((table) => table.name), <String>['products']);
    });
  });

  group('a declared type', () {
    Future<IntrospectedColumn> columnOf(String declaration) async {
      database.execute('CREATE TABLE t (id TEXT PRIMARY KEY, c $declaration)');
      return columnNamed(tableNamed(await introspect(database), 't'), 'c');
    }

    test('with no width is read as its base name', () async {
      final column = await columnOf('TEXT');

      expect(column.dataType, 'text');
      expect(column.maxLength, isNull);
      expect(column.numericPrecision, isNull);
    });

    test('with one width on a text type is a length', () async {
      // SQLite stores the declaration verbatim, so the width is read back out
      // of the string rather than from a catalog column.
      final column = await columnOf('VARCHAR(120)');

      expect(column.dataType, 'varchar');
      expect(column.maxLength, 120);
      expect(column.numericPrecision, isNull);
    });

    test('with one width on a numeric type is a precision', () async {
      final column = await columnOf('NUMERIC(12)');

      expect(column.maxLength, isNull, reason: 'a precision is not a length');
      expect(column.numericPrecision, 12);
      expect(column.numericScale, isNull);
    });

    test('with two widths is a precision and a scale', () async {
      final column = await columnOf('NUMERIC(12, 4)');

      expect(column.numericPrecision, 12);
      expect(column.numericScale, 4);
      expect(column.maxLength, isNull);
    });

    test('spanning two words keeps both', () async {
      final column = await columnOf('DOUBLE PRECISION');

      expect(column.dataType, 'double precision');
    });
  });

  group('nullability', () {
    test('follows NOT NULL, and a primary key is never null', () async {
      database.execute(
        'CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT NOT NULL, b TEXT)',
      );

      final table = tableNamed(await introspect(database), 't');
      expect(columnNamed(table, 'id').isNullable, isFalse);
      expect(columnNamed(table, 'a').isNullable, isFalse);
      expect(columnNamed(table, 'b').isNullable, isTrue);
    });

    test('a default is recorded', () async {
      database.execute(
        "CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT DEFAULT 'draft', b TEXT)",
      );

      final table = tableNamed(await introspect(database), 't');
      expect(columnNamed(table, 'a').hasDefault, isTrue);
      expect(columnNamed(table, 'b').hasDefault, isFalse);
    });
  });

  group('indexes', () {
    test('a single-column index marks its column', () async {
      database
        ..execute('CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT, b TEXT)')
        ..execute('CREATE INDEX t_a_idx ON t (a)');

      final table = tableNamed(await introspect(database), 't');
      expect(columnNamed(table, 'a').isIndexed, isTrue);
      expect(columnNamed(table, 'a').isUnique, isFalse);
      expect(columnNamed(table, 'b').isIndexed, isFalse);
    });

    test('a unique index marks the column unique', () async {
      database
        ..execute('CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT)')
        ..execute('CREATE UNIQUE INDEX t_a_key ON t (a)');

      expect(
        columnNamed(tableNamed(await introspect(database), 't'), 'a').isUnique,
        isTrue,
      );
    });

    test('a composite index marks neither column', () async {
      // A composite index says nothing about either column being separately
      // indexed, which is the only thing a schema class can express.
      database
        ..execute('CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT, b TEXT)')
        ..execute('CREATE INDEX t_ab_idx ON t (a, b)');

      final table = tableNamed(await introspect(database), 't');
      expect(columnNamed(table, 'a').isIndexed, isFalse);
      expect(columnNamed(table, 'b').isIndexed, isFalse);
    });
  });

  group('keys', () {
    test('a foreign key names its column and its target', () async {
      database
        ..execute('CREATE TABLE categories (id TEXT PRIMARY KEY)')
        ..execute(
          'CREATE TABLE products (id TEXT PRIMARY KEY, category_id TEXT '
          'REFERENCES categories (id))',
        );

      final table = tableNamed(await introspect(database), 'products');
      expect(table.foreignKeys.single.column, 'category_id');
      expect(table.foreignKeys.single.referencedTable, 'categories');
    });

    test('the primary key is read, and defaults to id without one', () async {
      database
        ..execute('CREATE TABLE keyed (pk TEXT PRIMARY KEY, a TEXT)')
        ..execute('CREATE TABLE keyless (a TEXT)');

      final tables = await introspect(database);
      expect(tableNamed(tables, 'keyed').primaryKey, 'pk');
      // A table another system owns may have none, and naming the convention
      // keeps the rest of the pipeline from handling a null.
      expect(tableNamed(tables, 'keyless').primaryKey, 'id');
    });
  });

  group('awkward identifiers', () {
    test('a name holding a double quote is read, not a syntax error', () async {
      // PRAGMA takes no bind parameters, so names are interpolated. `beak
      // introspect sqlite:legacy.db` exists to read databases Beak did not
      // create, where such a name is somebody else's decision.
      database.execute('CREATE TABLE "we""ird" (id TEXT PRIMARY KEY, a TEXT)');

      final tables = await introspect(database);
      expect(tables.map((table) => table.name), contains('we"ird'));
      expect(
        columnNamed(tableNamed(tables, 'we"ird'), 'a').name,
        'a',
        reason: 'the columns of an awkwardly named table are still read',
      );
    });

    test('an index whose name holds a quote is read', () async {
      database
        ..execute('CREATE TABLE t (id TEXT PRIMARY KEY, a TEXT)')
        ..execute('CREATE INDEX "od""d" ON t (a)');

      expect(
        columnNamed(tableNamed(await introspect(database), 't'), 'a').isIndexed,
        isTrue,
      );
    });

    test('quoted doubles an embedded quote', () {
      expect(SqliteIntrospector.quoted('plain'), '"plain"');
      expect(SqliteIntrospector.quoted('we"ird'), '"we""ird"');
    });
  });
}
