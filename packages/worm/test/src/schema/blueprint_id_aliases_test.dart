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

    test('id() and idUuid() describe the same column', () {
      expect(
        _described((t) => t.id()),
        _described((t) => t.idUuid()),
        reason: 'the aliases have drifted apart',
      );
    });

    test('intId() and idIncrements() describe the same column', () {
      expect(_described((t) => t.intId()), _described((t) => t.idIncrements()));
    });
  });
}

/// The single column [build] declares, as comparable values.
///
/// The aliases are only aliases if they produce the same description; what
/// each dialect then renders it as is the compilers' business, and their own
/// tests'.
(String, ColumnType, bool, bool) _described(
  void Function(BlueprintTable table) build,
) {
  final column = Blueprint.create('a', build).table.columns.single;
  return (column.name, column.type, column.isPrimaryKey, column.autoIncrement);
}
