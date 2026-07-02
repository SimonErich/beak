/// Spec aliases for `id()` and `intId()` on `BlueprintTable`.
library;

import 'package:test/test.dart';
import 'package:worm/src/schema/blueprint.dart';
import 'package:worm/src/schema/column_type.dart';

void main() {
  group('BlueprintTable id() / intId() aliases', () {
    test('id() declares a UUID primary key column named id', () {
      final blueprint = Blueprint.create('users', (table) {
        table.id();
      });
      final columns = blueprint.table.columns;
      expect(columns, hasLength(1));
      final column = columns.single;
      expect(column.name, 'id');
      expect(column.type, ColumnType.uuid);
      expect(column.isPrimaryKey, isTrue);
    });

    test('intId() declares an auto-incrementing int primary key', () {
      final blueprint = Blueprint.create('orders', (table) {
        table.intId();
      });
      final column = blueprint.table.columns.single;
      expect(column.name, 'id');
      expect(column.type, ColumnType.integer);
      expect(column.isPrimaryKey, isTrue);
      expect(column.autoIncrement, isTrue);
    });

    test('id() and idUuid() emit the same SQL fragment', () {
      final a = Blueprint.create('a', (t) => t.id()).toSql();
      final b = Blueprint.create('a', (t) => t.idUuid()).toSql();
      expect(a, b);
    });

    test('intId() and idIncrements() emit the same SQL fragment', () {
      final a = Blueprint.create('a', (t) => t.intId()).toSql();
      final b = Blueprint.create('a', (t) => t.idIncrements()).toSql();
      expect(a, b);
    });
  });
}
