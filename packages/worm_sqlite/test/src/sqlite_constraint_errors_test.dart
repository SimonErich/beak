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
}
