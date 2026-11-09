import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('QueryDescriptor.lock', () {
    test('is off by default and absent from the snapshot', () {
      const descriptor = QueryDescriptor(table: 'users');

      expect(descriptor.lock, isFalse);
      expect(descriptor.toMap(), isNot(contains('lock')));
    });

    test('copyWith sets it and keeps it when not mentioned', () {
      const descriptor = QueryDescriptor(table: 'users');

      final locked = descriptor.copyWith(lock: true);

      expect(locked.lock, isTrue);
      expect(locked.toMap()['lock'], isTrue);
      expect(locked.copyWith(limit: 1).lock, isTrue);
      expect(locked.copyWith(lock: false).lock, isFalse);
    });

    test('the in-memory adapter ignores it and returns the rows', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'users',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 2, 'name': 'Bob'},
            <String, Object?>{'id': 1, 'name': 'Alice'},
          ],
        ),
      );

      final rows = await adapter.transaction(
        (tx) => tx.select(
          const QueryDescriptor(
            table: 'users',
            columns: ['id'],
            orderBy: [SortClause('id')],
            lock: true,
          ),
        ),
      );

      expect(rows.map((row) => row['id']), [1, 2]);
    });
  });
}
