import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakTextColumn(key: 'description', label: 'Description');

  test('renders as text in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.text);
    }
  });

  test('holds String values', () {
    expect(column.valueType, String);
  });

  test('shares the base visibility defaults', () {
    expect(column.visibleOn, const {
      BeakContext.table,
      BeakContext.form,
      BeakContext.detail,
    });
  });
}
