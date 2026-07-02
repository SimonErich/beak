import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakMinLength(3);

  test('accepts strings at or past the boundary', () {
    expect(rule.validate('abc'), isNull);
    expect(rule.validate('abcd'), isNull);
  });

  test('rejects strings below the boundary, including empty', () {
    const message = 'Must be at least 3 characters.';
    expect(rule.validate('ab'), message);
    expect(rule.validate(''), message);
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(12), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'min_length');
  });
}
