import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakColorColumn(key: 'accent', label: 'Accent');

  test('renders as a color swatch in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.color);
    }
  });

  test('holds hex strings', () {
    expect(column.valueType, String);
  });
}
