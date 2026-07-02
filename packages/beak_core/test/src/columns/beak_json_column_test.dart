import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakJsonColumn(key: 'attributes', label: 'Attributes');

  test('renders as JSON in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.json);
    }
  });

  test('holds typed BeakJson values, never raw maps', () {
    expect(column.valueType, BeakJson);
  });
}
