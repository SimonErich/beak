import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakBoolColumn(key: 'active', label: 'Active');

  test('renders as a boolean in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.boolean);
    }
  });

  test('holds bool values', () {
    expect(column.valueType, bool);
  });

  test('state labels default to null', () {
    expect(column.trueLabel, isNull);
    expect(column.falseLabel, isNull);
  });

  test('stores custom state labels', () {
    const labelled = BeakBoolColumn(
      key: 'active',
      label: 'Active',
      trueLabel: 'Enabled',
      falseLabel: 'Disabled',
    );
    expect(labelled.trueLabel, 'Enabled');
    expect(labelled.falseLabel, 'Disabled');
  });
}
