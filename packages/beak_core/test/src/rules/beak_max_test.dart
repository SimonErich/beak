import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakMax(10);

  test('accepts numbers at or below the boundary', () {
    expect(rule.validate(10), isNull);
    expect(rule.validate(9.9), isNull);
    expect(rule.validate(-5), isNull);
  });

  test('rejects numbers above the boundary', () {
    expect(rule.validate(10.5), 'Must be at most 10.');
    expect(rule.validate(11), 'Must be at most 10.');
  });

  test('skips null and non-numeric values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate('11'), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'max');
  });
}
