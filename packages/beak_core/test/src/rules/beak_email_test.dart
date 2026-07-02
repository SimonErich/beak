import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakEmail();
  const message = 'Must be a valid email address.';

  test('accepts well-formed addresses', () {
    expect(rule.validate('user@example.com'), isNull);
    expect(rule.validate('user.name+tag@sub.domain.co'), isNull);
  });

  test('rejects malformed addresses', () {
    expect(rule.validate('not-an-email'), message);
    expect(rule.validate('a@b'), message);
    expect(rule.validate('user name@example.com'), message);
    expect(rule.validate('@example.com'), message);
    expect(rule.validate(''), message);
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(42), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'email');
  });
}
