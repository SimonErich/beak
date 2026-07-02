import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakIntColumn(key: 'stock', label: 'Stock');

  test('renders as a number in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.number);
    }
  });

  test('holds int values', () {
    expect(column.valueType, int);
  });

  test('bounds default to null', () {
    expect(column.min, isNull);
    expect(column.max, isNull);
  });

  test('stores min and max bounds', () {
    const bounded = BeakIntColumn(
      key: 'stock',
      label: 'Stock',
      min: 0,
      max: 100,
    );
    expect(bounded.min, 0);
    expect(bounded.max, 100);
  });
}
