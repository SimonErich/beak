import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Sample { one }

/// Exhaustive mapping over the sealed column family: adding a `BeakColumn`
/// variant breaks compilation here, forcing every consumer (frontend
/// renderer, backend mapper) to be revisited.
String kindOf(BeakColumn column) => switch (column) {
  BeakStringColumn() => 'string',
  BeakTextColumn() => 'text',
  BeakIntColumn() => 'int',
  BeakDecimalColumn() => 'decimal',
  BeakBoolColumn() => 'bool',
  BeakEnumColumn<Enum>() => 'enum',
  BeakDateTimeColumn() => 'dateTime',
  BeakImageColumn() => 'image',
  BeakFileColumn() => 'file',
  BeakJsonColumn() => 'json',
  BeakColorColumn() => 'color',
  BeakRichTextColumn() => 'richText',
  BeakCustomColumn() => 'custom',
};

/// One instance of every concrete column type.
const List<BeakColumn> allColumns = [
  BeakStringColumn(key: 'a', label: 'A'),
  BeakTextColumn(key: 'b', label: 'B'),
  BeakIntColumn(key: 'c', label: 'C'),
  BeakDecimalColumn(key: 'd', label: 'D'),
  BeakBoolColumn(key: 'e', label: 'E'),
  BeakEnumColumn<_Sample>(key: 'f', label: 'F', values: _Sample.values),
  BeakDateTimeColumn(key: 'g', label: 'G'),
  BeakImageColumn(key: 'h', label: 'H', storagePath: 'h'),
  BeakFileColumn(key: 'i', label: 'I', storagePath: 'i'),
  BeakJsonColumn(key: 'j', label: 'J'),
  BeakColorColumn(key: 'k', label: 'K'),
  BeakRichTextColumn(key: 'l', label: 'L'),
  BeakCustomColumn(key: 'm', label: 'M', tag: BeakColumnTag('m')),
];

void main() {
  test('the sealed column family switches exhaustively', () {
    expect(allColumns.map(kindOf), const [
      'string',
      'text',
      'int',
      'decimal',
      'bool',
      'enum',
      'dateTime',
      'image',
      'file',
      'json',
      'color',
      'richText',
      'custom',
    ]);
  });

  test('every column resolves an intent for every context', () {
    for (final column in allColumns) {
      for (final context in BeakContext.values) {
        expect(
          column.intentFor(context),
          isA<BeakRenderIntent>(),
          reason: '${column.key}/$context',
        );
      }
    }
  });

  test('every column declares a value type', () {
    for (final column in allColumns) {
      expect(column.valueType, isNotNull, reason: column.key);
    }
  });
}
