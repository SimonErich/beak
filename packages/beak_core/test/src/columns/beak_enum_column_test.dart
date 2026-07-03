import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _OrderStatus { pending, paid, cancelled }

/// Sample custom labeller for [_OrderStatus] values.
String _screaming(_OrderStatus value) => value.name.toUpperCase();

void main() {
  const column = BeakEnumColumn<_OrderStatus>(
    key: 'status',
    label: 'Status',
    values: _OrderStatus.values,
    badgeColors: {
      _OrderStatus.paid: BeakColor.success,
      _OrderStatus.cancelled: BeakColor.error,
    },
  );

  test('renders as a badge in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.badge);
    }
  });

  test('holds values of the declared enum type', () {
    expect(column.valueType, _OrderStatus);
  });

  test('exposes all selectable values', () {
    expect(column.values, _OrderStatus.values);
  });

  test('badgeColorFor returns the mapped color', () {
    expect(column.badgeColorFor(_OrderStatus.paid), BeakColor.success);
    expect(column.badgeColorFor(_OrderStatus.cancelled), BeakColor.error);
  });

  test('badgeColorFor returns null for unmapped values', () {
    expect(column.badgeColorFor(_OrderStatus.pending), isNull);
  });

  test('badge colors default to an empty mapping', () {
    const plain = BeakEnumColumn<_OrderStatus>(
      key: 'status',
      label: 'Status',
      values: _OrderStatus.values,
    );
    expect(plain.badgeColors, isEmpty);
    expect(plain.badgeColorFor(_OrderStatus.paid), isNull);
  });

  test('labelFor falls back to the enum name', () {
    expect(column.labelFor(_OrderStatus.pending), 'pending');
  });

  test('labelFor uses the labelOf callback when provided', () {
    const labelled = BeakEnumColumn<_OrderStatus>(
      key: 'status',
      label: 'Status',
      values: _OrderStatus.values,
      labelOf: _screaming,
    );
    expect(labelled.labelFor(_OrderStatus.paid), 'PAID');
  });

  test('defaultValue is null unless configured', () {
    expect(column.defaultValue, isNull);
    const preset = BeakEnumColumn<_OrderStatus>(
      key: 'status',
      label: 'Status',
      values: _OrderStatus.values,
      defaultValue: _OrderStatus.pending,
    );
    expect(preset.defaultValue, _OrderStatus.pending);
  });

  test('valueByName decodes wire names and rejects unknowns', () {
    const column = BeakEnumColumn<_OrderStatus>(
      key: 'status',
      label: 'Status',
      values: _OrderStatus.values,
    );
    expect(column.valueByName('paid'), _OrderStatus.paid);
    expect(column.valueByName('ghost'), isNull);
  });
}
