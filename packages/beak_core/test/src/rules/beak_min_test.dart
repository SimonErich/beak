import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakMin(0);

  test('accepts numbers at or above the boundary', () {
    expect(rule.validate(0), isNull);
    expect(rule.validate(0.5), isNull);
    expect(rule.validate(100), isNull);
  });

  test('rejects numbers below the boundary', () {
    expect(rule.validate(-1), 'Must be at least 0.');
    expect(const BeakMin(0.5).validate(0.4), 'Must be at least 0.5.');
  });

  test('skips null and non-numeric values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate('-1'), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'min');
  });
}
