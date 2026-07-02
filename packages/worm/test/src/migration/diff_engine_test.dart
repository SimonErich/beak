import 'package:test/test.dart';
import 'package:worm/worm.dart';

const _id = ColumnSnapshot(
  name: 'id',
  type: ColumnType.uuid,
  isPrimaryKey: true,
);

void main() {
  group('DiffEngine', () {
    test('reports addTable for new tables', () {
      final diff = DiffEngine.diff(
        from: const <TableSchema>[],
        to: <TableSchema>[
          const TableSchema(name: 'users', columns: <ColumnSnapshot>[_id]),
        ],
      );
      expect(diff.changes, isNotEmpty);
      expect(diff.changes.first.kind, SchemaChangeKind.addTable);
    });

    test('reports addColumn when a column appears', () {
      const from = TableSchema(name: 'users', columns: <ColumnSnapshot>[_id]);
      const to = TableSchema(
        name: 'users',
        columns: <ColumnSnapshot>[
          _id,
          ColumnSnapshot(name: 'email', type: ColumnType.string),
        ],
      );
      final diff = DiffEngine.diff(
        from: <TableSchema>[from],
        to: <TableSchema>[to],
      );
      expect(
        diff.changes.any(
          (c) => c.kind == SchemaChangeKind.addColumn && c.column == 'email',
        ),
        isTrue,
      );
    });

    test('reports dropColumn as destructive', () {
      const from = TableSchema(
        name: 'users',
        columns: <ColumnSnapshot>[
          _id,
          ColumnSnapshot(name: 'legacy', type: ColumnType.string),
        ],
      );
      const to = TableSchema(name: 'users', columns: <ColumnSnapshot>[_id]);
      final diff = DiffEngine.diff(
        from: <TableSchema>[from],
        to: <TableSchema>[to],
      );
      final drop = diff.changes.singleWhere(
        (c) => c.kind == SchemaChangeKind.dropColumn,
      );
      expect(drop.destructive, isTrue);
      expect(diff.hasDestructive, isTrue);
    });

    test('reports column type change as destructive', () {
      const from = TableSchema(
        name: 'users',
        columns: <ColumnSnapshot>[
          ColumnSnapshot(name: 'age', type: ColumnType.string),
        ],
      );
      const to = TableSchema(
        name: 'users',
        columns: <ColumnSnapshot>[
          ColumnSnapshot(name: 'age', type: ColumnType.integer),
        ],
      );
      final diff = DiffEngine.diff(
        from: <TableSchema>[from],
        to: <TableSchema>[to],
      );
      final change = diff.changes.singleWhere(
        (c) => c.kind == SchemaChangeKind.changeColumnType,
      );
      expect(change.previousType, ColumnType.string);
      expect(change.newType, ColumnType.integer);
      expect(change.destructive, isTrue);
    });

    test('reports dropTable as destructive', () {
      const from = TableSchema(name: 'users', columns: <ColumnSnapshot>[_id]);
      final diff = DiffEngine.diff(
        from: <TableSchema>[from],
        to: const <TableSchema>[],
      );
      final drop = diff.changes.singleWhere(
        (c) => c.kind == SchemaChangeKind.dropTable,
      );
      expect(drop.destructive, isTrue);
    });

    test('empty diff is empty', () {
      final diff = DiffEngine.diff(
        from: const <TableSchema>[],
        to: const <TableSchema>[],
      );
      expect(diff.isEmpty, isTrue);
    });
  });
}
