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

  test('matches the address shape on the edges', () {
    // One @, a non-empty local part, and a dot with a character on each side
    // in the domain; no whitespace anywhere.
    expect(rule.validate('a@b.c'), isNull);
    expect(rule.validate('a@b..c'), isNull);
    expect(rule.validate('a@b.c.'), isNull);
    expect(rule.validate('a@b.'), message);
    expect(rule.validate('a@.b'), message);
    expect(rule.validate('a@b@c.d'), message);
    expect(rule.validate('a@@c.d'), message);
    expect(rule.validate('a@b .c'), message);
    expect(rule.validate('a@b.c\n'), message);
    expect(rule.validate('a@b.c\u00a0'), message);
  });

  test('refuses an address longer than the 254 characters an address has', () {
    final local = 'a' * 64;
    expect(rule.validate('$local@${'b' * 180}.com'), isNull);
    expect(rule.validate('$local@${'b' * 200}.com'), message);
  });

  test('a hostile string is refused in linear time', () {
    // A backtracking pattern needs seconds for twenty thousand dots and hours
    // for a megabyte, and validation runs on the server's only isolate.
    final hostile = 'a@${'.' * 1000000} ';
    final stopwatch = Stopwatch()..start();
    expect(rule.validate(hostile), message);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(42), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'email');
  });
}
