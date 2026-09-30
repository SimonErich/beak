import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// The constraint failures a caller can cause map to typed exceptions, so a
/// server can tell "you sent something the database refuses" from "the
/// database is broken".
void main() {
  late SqliteAdapter adapter;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.rawExecute(
      'CREATE TABLE products (id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'price INTEGER CHECK (price >= 0))',
      const [],
    );
  });

  tearDown(() => adapter.disconnect());

  Future<Map<String, Object?>> insert(Map<String, Object?> values) =>
      adapter.insert(InsertDescriptor(table: 'products', values: values));

  test(
    'a NOT NULL violation is a CheckConstraintException naming the column',
    () {
      expect(
        () => insert({'id': 'a', 'name': null, 'price': 1}),
        throwsA(
          isA<CheckConstraintException>()
              .having((e) => e.table, 'table', 'products')
              .having((e) => e.column, 'column', 'name'),
        ),
      );
    },
  );

  test('a CHECK violation is a CheckConstraintException', () {
    expect(
      () => insert({'id': 'a', 'name': 'x', 'price': -1}),
      throwsA(
        isA<CheckConstraintException>().having(
          (e) => e.table,
          'table',
          'products',
        ),
      ),
    );
  });

  test('a duplicate key is still a UniqueConstraintException', () async {
    await insert({'id': 'a', 'name': 'x', 'price': 1});
    expect(
      () => insert({'id': 'a', 'name': 'y', 'price': 2}),
      throwsA(isA<UniqueConstraintException>()),
    );
  });

  group('a foreign key', () {
    setUp(() async {
      await adapter.rawExecute(
        'CREATE TABLE stock (id TEXT PRIMARY KEY, product_id TEXT NOT NULL '
        'REFERENCES products (id) ON DELETE RESTRICT)',
        const [],
      );
      await adapter.rawExecute(
        "INSERT INTO products (id, name, price) VALUES ('p', 'x', 1)",
        const [],
      );
      await adapter.rawExecute(
        "INSERT INTO stock (id, product_id) VALUES ('s', 'p')",
        const [],
      );
    });

    test('that restricts a delete is a ForeignKeyException', () {
      expect(
        () => adapter.delete(const DeleteDescriptor(table: 'products')),
        throwsA(isA<ForeignKeyException>()),
      );
    });

    test('that restricts a delete inside a transaction is typed too', () {
      expect(
        () => adapter.transaction(
          (tx) => tx.delete(const DeleteDescriptor(table: 'products')),
        ),
        throwsA(isA<ForeignKeyException>()),
      );
    });

    test('that points at no row is a ForeignKeyException', () {
      expect(
        () => adapter.insert(
          const InsertDescriptor(
            table: 'stock',
            values: {'id': 'x', 'product_id': 'nope'},
          ),
        ),
        throwsA(isA<ForeignKeyException>()),
      );
    });
  });
}
