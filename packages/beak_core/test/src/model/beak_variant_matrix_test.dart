import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('matrix previews only missing combinations with stable identity', () {
    final matrix = BeakVariantMatrix([
      BeakVariantAxis(key: 'size', label: 'Size', values: ['S', 'L']),
      BeakVariantAxis(key: 'color', label: 'Color', values: ['Blue', 'Red']),
    ]);
    final existing = BeakVariantCombination({'color': 'Blue', 'size': 'S'});
    final preview = matrix.preview(existing: [existing]);
    expect(preview, hasLength(3));
    expect(preview.first.label, 'S / Red');
    expect(preview.map((combination) => combination.key).toSet(), hasLength(3));
    expect(
      existing.key,
      BeakVariantCombination({'size': 'S', 'color': 'Blue'}).key,
    );
    expect(
      BeakVariantCombination({'a': 'x:y'}).key,
      isNot(BeakVariantCombination({'a:x': 'y'}).key),
    );
    expect(BeakVariantMatrix([]).preview(), isEmpty);
  });

  test('bounds and ambiguous axes fail before allocating a large draft', () {
    final axis = BeakVariantAxis(
      key: 'size',
      label: 'Size',
      values: ['S', 'L'],
    );
    expect(
      () => BeakVariantMatrix([axis, axis]),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakVariantAxis(key: 'size', label: 'Size', values: ['S', 'S']),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakVariantAxis(key: 'size', label: 'Size', values: []),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakVariantMatrix([axis], maximumCombinations: 1),
      throwsA(isA<BeakValidationException>()),
    );
    expect(
      () => BeakVariantMatrix([axis], maximumCombinations: 0),
      throwsA(isA<BeakConfigurationException>()),
    );
    final values = ['S'];
    final copied = BeakVariantAxis(key: 'size', label: 'Size', values: values);
    values.add('L');
    expect(copied.values, ['S']);
  });
}
