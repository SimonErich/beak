/// Proof that a `DROP COLUMN` an old libsqlite3 cannot run is refused by
/// name, with the version floor and the way out in the message.
///
/// Without the gate the emitted statement reaches the driver, comes back as a
/// bare syntax error, and is mapped to a generic `QueryException` that leaves
/// the reader guessing. The runner's injectable version is what makes this
/// testable at all: the alternative is linking a decade-old SQLite.
library;

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  late Database database;

  setUp(() {
    database = sqlite3.openInMemory()
      ..execute('CREATE TABLE products (id TEXT PRIMARY KEY, status TEXT)');
  });

  tearDown(() => database.close());

  // Through the public adapter, which is what a project holds: the version
  // seam exists so a caller running against an embedded old SQLite can pin
  // it, and a test that reached past it into `src/` would prove less.
  SqliteAdapter adapterOn(String libraryVersion) =>
      SqliteAdapter(database, libraryVersion: libraryVersion);

  List<String> columns() => <String>[
    for (final row in database.select('PRAGMA table_info(products)'))
      if (row['name'] case final String name) name,
  ];

  Future<void> dropStatusOn(SqliteAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.alterTable(
      table: 'products',
      alterations: <SchemaAlteration>[SchemaDropColumn('status')],
    ),
  );

  test(
    'a library below 3.35 is refused by name, and the column stays',
    () async {
      await expectLater(
        () => dropStatusOn(adapterOn('3.34.1')),
        throwsA(
          isA<UnsupportedOperationException>()
              .having(
                (error) => error.operation,
                'operation',
                'alter.dropColumn',
              )
              .having((error) => error.adapter, 'adapter', 'SqliteAdapter')
              .having(
                (error) => error.message,
                'message',
                allOf(
                  contains('3.35'),
                  contains('3.34.1'),
                  contains('rawExecute'),
                  contains('Postgres'),
                ),
              ),
        ),
      );

      expect(
        columns(),
        contains('status'),
        reason: 'a refusal must not half-apply the alteration',
      );
    },
  );

  test('a library at or above 3.35 drops the column', () async {
    await dropStatusOn(adapterOn('3.35.0'));

    expect(columns(), isNot(contains('status')));
  });

  test('ADD COLUMN is untouched on a library below 3.35', () async {
    // ADD COLUMN has been in SQLite since 3.2. Gating it on the DROP COLUMN
    // floor would refuse migrations an old library runs happily.
    await adapterOn('3.9.0').executeSchema(
      const SchemaDescriptor.alterTable(
        table: 'products',
        alterations: <SchemaAlteration>[
          SchemaAddColumn(
            SchemaColumn(
              name: 'stock',
              type: ColumnType.integer,
              nullable: true,
            ),
          ),
        ],
      ),
    );

    expect(columns(), contains('stock'));
  });

  test('an uninjected adapter reads the linked library, not a constant', () {
    // The default has to be the real version, or the gate would refuse
    // statements a current SQLite runs perfectly well.
    expect(() => dropStatusOn(SqliteAdapter(database)), returnsNormally);
  });
}
