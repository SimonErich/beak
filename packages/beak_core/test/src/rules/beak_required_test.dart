import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const rule = BeakRequired();
  const message = 'This field is required.';

  test('rejects null', () {
    expect(rule.validate(null), message);
  });

  test('rejects empty and whitespace-only strings', () {
    expect(rule.validate(''), message);
    expect(rule.validate('   '), message);
  });

  test('rejects empty collections', () {
    expect(rule.validate(const <Object?>[]), message);
    expect(rule.validate(const <Object?>{}), message);
  });

  test('accepts present values, including false and zero', () {
    expect(rule.validate('x'), isNull);
    expect(rule.validate(0), isNull);
    expect(rule.validate(false), isNull);
    expect(rule.validate(const [1]), isNull);
  });

  test(
    'allowEmpty distinguishes nonnull collections from minimum item counts',
    () {
      const nonnull = BeakRequired(allowEmpty: true);
      expect(nonnull.validate(null), message);
      for (final value in <Object>[
        '',
        <String>[],
        <String, Object?>{},
        const BeakJsonObject({}),
      ]) {
        expect(nonnull.validate(value), isNull);
        expect(rule.validate(value), message);
      }
    },
  );

  test('has a stable id', () {
    expect(rule.id, 'required');
  });
}
