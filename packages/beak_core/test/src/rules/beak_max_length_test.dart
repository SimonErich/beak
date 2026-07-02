import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakMaxLength(3);

  test('accepts strings up to the boundary', () {
    expect(rule.validate(''), isNull);
    expect(rule.validate('ab'), isNull);
    expect(rule.validate('abc'), isNull);
  });

  test('rejects strings past the boundary', () {
    expect(rule.validate('abcd'), 'Must be at most 3 characters.');
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(1234), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'max_length');
  });
}
