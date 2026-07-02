import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakMaxFileSize(1024);

  test('accepts sizes up to the boundary', () {
    expect(rule.validate(0), isNull);
    expect(rule.validate(1024), isNull);
  });

  test('rejects sizes past the boundary', () {
    expect(rule.validate(1025), 'File must be at most 1024 bytes.');
  });

  test('skips null and non-integer values', () {
    expect(rule.validate(null), isNull);
    expect(rule.validate('big'), isNull);
  });

  test('has a stable id', () {
    expect(rule.id, 'max_file_size');
  });
}
