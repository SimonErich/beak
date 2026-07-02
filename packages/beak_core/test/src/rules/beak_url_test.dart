import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakUrl();
  const message = 'Must be a valid URL.';

  test('accepts absolute http and https URLs', () {
    expect(rule.validate('https://example.com'), isNull);
    expect(rule.validate('https://example.com/path?q=1'), isNull);
    expect(rule.validate('http://localhost:8080/admin'), isNull);
  });

  test('rejects other schemes, relative and malformed URLs', () {
    expect(rule.validate('ftp://example.com'), message);
    expect(rule.validate('example.com'), message);
    expect(rule.validate('https://'), message);
    expect(rule.validate('not a url'), message);
    expect(rule.validate(''), message);
  });

  test('skips null and non-string values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate(80), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'url');
  });
}
