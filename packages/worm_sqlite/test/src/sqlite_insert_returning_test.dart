/// What `insert(..., returning:)` answers for columns the statement did not
/// supply: the database's own values (a serial key, a column default).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  late SqliteAdapter adapter;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'things',
        columns: <SchemaColumn>[
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            autoIncrement: true,
          ),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(
            name: 'status',
            type: ColumnType.text,
            defaultValue: 'new',
          ),
        ],
      ),
    );
  });
  tearDown(() => adapter.disconnect());

  test('returns the serial key the database assigned', () async {
    final first = await adapter.insert(
      const InsertDescriptor(
        table: 'things',
        values: <String, Object?>{'name': 'one'},
        returning: <String>['id', 'name'],
      ),
    );
    final second = await adapter.insert(
      const InsertDescriptor(
        table: 'things',
        values: <String, Object?>{'name': 'two'},
        returning: <String>['id', 'name'],
      ),
    );

    expect(first, <String, Object?>{'id': 1, 'name': 'one'});
    expect(second, <String, Object?>{'id': 2, 'name': 'two'});
  });

  test('returns a column default the statement did not supply', () async {
    final row = await adapter.insert(
      const InsertDescriptor(
        table: 'things',
        values: <String, Object?>{'name': 'one'},
        returning: <String>['id', 'status'],
      ),
    );

    expect(row, <String, Object?>{'id': 1, 'status': 'new'});
  });

  test('keeps a key the caller supplied', () async {
    final row = await adapter.insert(
      const InsertDescriptor(
        table: 'things',
        values: <String, Object?>{'id': 40, 'name': 'chosen'},
        returning: <String>['id', 'name'],
      ),
    );

    expect(row, <String, Object?>{'id': 40, 'name': 'chosen'});
  });

  test('answers the supplied values when nothing was asked for', () async {
    final row = await adapter.insert(
      const InsertDescriptor(
        table: 'things',
        values: <String, Object?>{'name': 'one'},
      ),
    );

    expect(row, <String, Object?>{'name': 'one'});
  });

  test('reads back inside a transaction', () async {
    final row = await adapter.transaction(
      (tx) => tx.insert(
        const InsertDescriptor(
          table: 'things',
          values: <String, Object?>{'name': 'one'},
          returning: <String>['id'],
        ),
      ),
    );

    expect(row['id'], 1);
  });
}
