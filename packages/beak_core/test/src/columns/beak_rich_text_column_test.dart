import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakRichTextColumn(key: 'body', label: 'Body');

  test('renders as rich text in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.richText);
    }
  });

  test('holds String values', () {
    expect(column.valueType, String);
  });
}
