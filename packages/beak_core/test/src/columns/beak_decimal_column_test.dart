import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('renders as a plain number without prefix or suffix', () {
    const column = BeakDecimalColumn(key: 'weight', label: 'Weight');
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.number);
    }
  });

  test('renders as currency when a prefix is set', () {
    const column = BeakDecimalColumn(key: 'price', label: 'Price', prefix: '€');
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.currency);
    }
  });

  test('renders as currency when only a suffix is set', () {
    const column = BeakDecimalColumn(
      key: 'price',
      label: 'Price',
      suffix: 'EUR',
    );
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.currency);
    }
  });

  test('holds double values', () {
    const column = BeakDecimalColumn(key: 'price', label: 'Price');
    expect(column.valueType, double);
  });

  test('defaults to two fraction digits and no decorations', () {
    const column = BeakDecimalColumn(key: 'price', label: 'Price');
    expect(column.precision, 2);
    expect(column.prefix, isNull);
    expect(column.suffix, isNull);
  });

  test('stores precision, prefix and suffix', () {
    const column = BeakDecimalColumn(
      key: 'price',
      label: 'Price',
      precision: 4,
      prefix: r'$',
      suffix: 'per unit',
    );
    expect(column.precision, 4);
    expect(column.prefix, r'$');
    expect(column.suffix, 'per unit');
  });
}
