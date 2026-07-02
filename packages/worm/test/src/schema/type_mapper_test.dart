import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('TypeMapper.toSqlType', () {
    test('maps every ColumnType to a non-empty SQL type', () {
      for (final type in ColumnType.values) {
        final sql = TypeMapper.toSqlType(
          type,
          elementType: type == ColumnType.array ? ColumnType.integer : null,
        );
        expect(sql, isNotEmpty);
      }
    });

    test('parameterizes string and decimal types', () {
      expect(
        TypeMapper.toSqlType(ColumnType.string, length: 64),
        'VARCHAR(64)',
      );
      expect(
        TypeMapper.toSqlType(ColumnType.decimal, precision: 8, scale: 4),
        'NUMERIC(8,4)',
      );
    });

    test('renders array element type', () {
      expect(
        TypeMapper.toSqlType(ColumnType.array, elementType: ColumnType.uuid),
        'UUID[]',
      );
    });
  });

  group('TypeMapper.toMongoType', () {
    test('maps every ColumnType to a non-empty BSON tag', () {
      for (final type in ColumnType.values) {
        final tag = TypeMapper.toMongoType(type);
        expect(tag, isNotEmpty);
      }
    });

    test('maps decimal to decimal and dateTime to date', () {
      expect(TypeMapper.toMongoType(ColumnType.decimal), 'decimal');
      expect(TypeMapper.toMongoType(ColumnType.dateTime), 'date');
      expect(TypeMapper.toMongoType(ColumnType.uuid), 'string');
    });
  });
}
