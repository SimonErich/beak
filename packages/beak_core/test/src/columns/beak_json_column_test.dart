import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakJsonColumn(key: 'attributes', label: 'Attributes');

  test('renders as JSON in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.json);
    }
  });

  test('carries its JSON document as text, decodable into a BeakJson tree', () {
    expect(column.valueType, String);
    expect(
      BeakJson.decode('{"a": 1}'),
      const BeakJsonObject({'a': BeakJsonNumber(1)}),
    );
  });
}
