import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakPattern(r'^\d{4}$');

  test('accepts matching strings', () {
    expect(rule.validate('1234'), isNull);
  });

  test('rejects non-matching strings with the default message', () {
    expect(rule.validate('12345'), 'Must match the expected format.');
    expect(rule.validate('abcd'), 'Must match the expected format.');
  });

  test('uses the custom message when provided', () {
    const custom = BeakPattern(r'^\d+$', message: 'Digits only.');
    expect(custom.validate('x'), 'Digits only.');
    expect(custom.validate('7'), isNull);
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(1234), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'pattern');
  });
}
