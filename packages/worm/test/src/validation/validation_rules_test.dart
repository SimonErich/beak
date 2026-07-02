import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Required', () {
    const rule = Required();
    test('rejects null', () {
      expect(rule.validate(null).isInvalid, isTrue);
    });
    test('rejects empty string', () {
      expect(rule.validate('').isInvalid, isTrue);
    });
    test('rejects empty list', () {
      expect(rule.validate(<int>[]).isInvalid, isTrue);
    });
    test('rejects empty map', () {
      expect(rule.validate(<String, int>{}).isInvalid, isTrue);
    });
    test('accepts non-empty string', () {
      expect(rule.validate('x').isValid, isTrue);
    });
    test('accepts zero (non-empty value)', () {
      expect(rule.validate(0).isValid, isTrue);
    });
    test('reports the configured message', () {
      const custom = Required(message: 'Required please.');
      expect(custom.validate(null).message, 'Required please.');
    });
  });

  group('Email', () {
    const rule = Email();
    test('accepts a typical address', () {
      expect(rule.validate('alice@example.com').isValid, isTrue);
    });
    test('rejects missing local part', () {
      expect(rule.validate('@example.com').isInvalid, isTrue);
    });
    test('rejects missing tld', () {
      expect(rule.validate('alice@example').isInvalid, isTrue);
    });
    test('rejects non-string', () {
      expect(rule.validate(42).isInvalid, isTrue);
    });
    test('skips null', () {
      expect(rule.validate(null).isValid, isTrue);
    });
  });

  group('MinLength', () {
    const rule = MinLength(3);
    test('accepts string at boundary', () {
      expect(rule.validate('abc').isValid, isTrue);
    });
    test('rejects shorter string', () {
      expect(rule.validate('ab').isInvalid, isTrue);
    });
    test('accepts list at boundary', () {
      expect(rule.validate(<int>[1, 2, 3]).isValid, isTrue);
    });
  });

  group('MaxLength', () {
    const rule = MaxLength(3);
    test('accepts string at boundary', () {
      expect(rule.validate('abc').isValid, isTrue);
    });
    test('rejects longer string', () {
      expect(rule.validate('abcd').isInvalid, isTrue);
    });
  });

  group('Min / Max', () {
    test('Min rejects below bound', () {
      expect(const Min(5).validate(4).isInvalid, isTrue);
    });
    test('Min accepts at bound', () {
      expect(const Min(5).validate(5).isValid, isTrue);
    });
    test('Min rejects non-numeric', () {
      expect(const Min(5).validate('x').isInvalid, isTrue);
    });
    test('Max rejects above bound', () {
      expect(const Max(5).validate(6).isInvalid, isTrue);
    });
    test('Max accepts at bound', () {
      expect(const Max(5).validate(5).isValid, isTrue);
    });
  });

  group('Regex', () {
    final rule = Regex(RegExp(r'^[A-Z]+$'));
    test('accepts match', () {
      expect(rule.validate('ABC').isValid, isTrue);
    });
    test('rejects mismatch', () {
      expect(rule.validate('abc').isInvalid, isTrue);
    });
  });

  group('In / NotIn', () {
    test('In accepts member', () {
      expect(const In(<String>['a', 'b']).validate('a').isValid, isTrue);
    });
    test('In rejects non-member', () {
      expect(const In(<String>['a', 'b']).validate('z').isInvalid, isTrue);
    });
    test('NotIn rejects member', () {
      expect(const NotIn(<String>['a']).validate('a').isInvalid, isTrue);
    });
    test('NotIn accepts non-member', () {
      expect(const NotIn(<String>['a']).validate('b').isValid, isTrue);
    });
  });

  group('Url', () {
    const rule = Url();
    test('accepts absolute URL', () {
      expect(rule.validate('https://worm.dev/docs').isValid, isTrue);
    });
    test('rejects relative path', () {
      expect(rule.validate('/docs').isInvalid, isTrue);
    });
    test('rejects opaque mailto', () {
      expect(rule.validate('mailto:a@b.com').isInvalid, isTrue);
    });
  });

  group('Uuid', () {
    const rule = Uuid();
    test('accepts v4 UUID', () {
      expect(
        rule.validate('550e8400-e29b-41d4-a716-446655440000').isValid,
        isTrue,
      );
    });
    test('rejects malformed UUID', () {
      expect(rule.validate('not-a-uuid').isInvalid, isTrue);
    });
  });

  group('Date / After / Before', () {
    final base = DateTime.utc(2026);
    test('Date accepts iso string', () {
      expect(const DateRule().validate('2026-01-01T00:00:00Z').isValid, isTrue);
    });
    test('Date rejects junk', () {
      expect(const DateRule().validate('nope').isInvalid, isTrue);
    });
    test('After accepts later date', () {
      final later = base.add(const Duration(days: 1));
      expect(After(base).validate(later).isValid, isTrue);
    });
    test('After rejects earlier date', () {
      final earlier = base.subtract(const Duration(days: 1));
      expect(After(base).validate(earlier).isInvalid, isTrue);
    });
    test('Before accepts earlier date', () {
      final earlier = base.subtract(const Duration(days: 1));
      expect(Before(base).validate(earlier).isValid, isTrue);
    });
    test('Before rejects later date', () {
      final later = base.add(const Duration(days: 1));
      expect(Before(base).validate(later).isInvalid, isTrue);
    });
  });

  group('Confirmed', () {
    test('accepts matching value', () {
      expect(const Confirmed('s3cret').validate('s3cret').isValid, isTrue);
    });
    test('rejects mismatched value', () {
      expect(const Confirmed('s3cret').validate('wrong').isInvalid, isTrue);
    });
  });

  group('Validator accumulation', () {
    test('accumulates every failing rule for a single field', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[MinLength(5), Required()],
      });
      final errors = await validator.validate(<String, Object?>{'name': ''});
      expect(errors['name'], hasLength(2));
    });

    test('Email passes when key is absent', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'email': <ValidationRule>[Email()],
      });
      final errors = await validator.validate(<String, Object?>{});
      expect(errors, isEmpty);
    });
  });

  group('null passes for every non-Required rule', () {
    final nullPassing = <String, ValidationRule>{
      'Email': const Email(),
      'MinLength': const MinLength(3),
      'MaxLength': const MaxLength(3),
      'Min': const Min(10),
      'Max': const Max(10),
      'In': const In(<String>['a']),
      'NotIn': const NotIn(<String>['a']),
      'Regex': Regex(RegExp(r'^x$')),
      'Url': const Url(),
      'Uuid': const Uuid(),
      'Date': const DateRule(),
      'After': After(DateTime.utc(2020)),
      'Before': Before(DateTime.utc(2020)),
      'Confirmed': const Confirmed('secret'),
    };
    for (final entry in nullPassing.entries) {
      test('${entry.key}.validate(null) is valid', () {
        expect(entry.value.validate(null), isA<ValidationResult>());
        final outcome = entry.value.validate(null);
        if (outcome is ValidationResult) {
          expect(outcome.isValid, isTrue);
        } else {
          fail('${entry.key} returned a Future for null input.');
        }
      });
    }
  });

  group('validation rule literal examples', () {
    test('Required.validate(null) is invalid with non-empty message', () {
      final outcome = const Required().validate(null);
      expect(outcome.isInvalid, isTrue);
      expect(outcome.message, isNotEmpty);
    });
    test('Required.validate("") is invalid with non-empty message', () {
      final outcome = const Required().validate('');
      expect(outcome.isInvalid, isTrue);
      expect(outcome.message, isNotEmpty);
    });
    test('Required.validate("hello") is valid', () {
      expect(const Required().validate('hello').isValid, isTrue);
    });
    test('Email.validate("bad") is invalid with non-empty message', () {
      final outcome = const Email().validate('bad');
      expect(outcome.isInvalid, isTrue);
      expect(outcome.message, isNotEmpty);
    });
    test('Email.validate("a@b.com") is valid', () {
      expect(const Email().validate('a@b.com').isValid, isTrue);
    });
    test('MinLength(5).validate("hi") is invalid', () {
      expect(const MinLength(5).validate('hi').isInvalid, isTrue);
    });
    test('MinLength(5).validate("hello") is valid', () {
      expect(const MinLength(5).validate('hello').isValid, isTrue);
    });
    test('Min(10).validate(9) is invalid', () {
      expect(const Min(10).validate(9).isInvalid, isTrue);
    });
    test('Min(10).validate(10) is valid', () {
      expect(const Min(10).validate(10).isValid, isTrue);
    });
    test('In([a,b]).validate(c) is invalid with non-empty message', () {
      final outcome = const In(<String>['a', 'b']).validate('c');
      expect(outcome.isInvalid, isTrue);
      expect(outcome.message, isNotEmpty);
    });
    test('Confirmed(other_value).validate(secret) is invalid', () {
      expect(
        const Confirmed('other_value').validate('secret').isInvalid,
        isTrue,
      );
    });
    test('Confirmed(secret).validate(secret) is valid', () {
      expect(const Confirmed('secret').validate('secret').isValid, isTrue);
    });
    test('After(2020).validate("2019-01-01") is invalid', () {
      final outcome = After(DateTime(2020)).validate('2019-01-01');
      expect(outcome.isInvalid, isTrue);
      expect(outcome.message, isNotEmpty);
    });
    test('After(2020).validate("2021-01-01") is valid', () {
      expect(After(DateTime(2020)).validate('2021-01-01').isValid, isTrue);
    });
  });
}
