import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakInList<String>(['draft', 'published']);

  test('accepts values from the list', () {
    expect(rule.validate('draft'), isNull);
    expect(rule.validate('published'), isNull);
  });

  test('rejects values outside the list', () {
    expect(rule.validate('archived'), 'Must be one of: draft, published.');
    expect(rule.validate(42), 'Must be one of: draft, published.');
  });

  test('works for any element type', () {
    const numeric = BeakInList<int>([1, 2]);
    expect(numeric.validate(2), isNull);
    expect(numeric.validate(3), 'Must be one of: 1, 2.');
  });

  test('skips null', () {
    expect(rule.validate(null), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'in_list');
  });
}
