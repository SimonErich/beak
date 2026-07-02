import 'package:test/test.dart';
import 'package:worm/worm.dart';

final class _AlwaysValidAsync extends ValidationRule {
  const _AlwaysValidAsync();

  @override
  String get name => 'always-valid-async';

  @override
  Future<ValidationResult> validate(Object? value) async =>
      const ValidationResult.valid();
}

final class _FakeUser implements Validatable {
  const _FakeUser({required this.email, required this.name, this.id});

  final String? email;
  final String? name;
  final Object? id;

  @override
  String get tableName => 'users';

  @override
  Object? get primaryKeyValue => id;

  @override
  Map<String, List<ValidationRule>> validationRules() =>
      const <String, List<ValidationRule>>{
        'email': <ValidationRule>[Required(), Email()],
        'name': <ValidationRule>[Required(), MinLength(2)],
      };

  @override
  Map<String, Object?> validationValues() => <String, Object?>{
    'email': email,
    'name': name,
  };
}

void main() {
  group('Validator', () {
    test('returns empty map on success', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required(), MinLength(2)],
      });
      final errors = await validator.validate(<String, Object?>{'name': 'Ada'});
      expect(errors, isEmpty);
    });

    test('aggregates multiple field errors', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required()],
        'email': <ValidationRule>[Required(), Email()],
      });
      final errors = await validator.validate(<String, Object?>{
        'name': '',
        'email': 'nope',
      });
      expect(errors.keys, containsAll(<String>['name', 'email']));
      expect(errors['name'], isNotEmpty);
      expect(errors['email'], isNotEmpty);
    });

    test('runs every rule per field', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'pwd': <ValidationRule>[Required(), MinLength(8)],
      });
      final errors = await validator.validate(<String, Object?>{'pwd': 'x'});
      expect(errors['pwd']!.length, 1);
    });

    test('validateOrThrow throws aggregated exception', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required()],
      });
      Object? caught;
      try {
        await validator.validateOrThrow(<String, Object?>{'name': ''});
      } on ValidationException catch (e) {
        caught = e;
      }
      expect(caught, isA<ValidationException>());
      final ex = caught! as ValidationException;
      expect(ex.errors['name'], isNotEmpty);
    });

    test('validateSync throws when a rule is async', () {
      const validator = Validator(<String, List<ValidationRule>>{
        'email': <ValidationRule>[_AlwaysValidAsync()],
      });
      expect(
        () => validator.validateSync(<String, Object?>{'email': 'a'}),
        throwsStateError,
      );
    });
  });

  group('Validator literal examples', () {
    test('const Validator is constructible', () {
      const validator = Validator(<String, List<ValidationRule>>{
        'email': <ValidationRule>[Email()],
      });
      expect(validator.rules, isNotEmpty);
    });

    test('validateOrThrow throws on invalid email', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'email': <ValidationRule>[Email()],
      });
      ValidationException? caught;
      try {
        await validator.validateOrThrow(<String, Object?>{'email': 'bad'});
      } on ValidationException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.errors['email'], hasLength(1));
    });

    test('validateOrThrow does not throw for valid email', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'email': <ValidationRule>[Email()],
      });
      await validator.validateOrThrow(<String, Object?>{'email': 'a@b.com'});
    });

    test('validateOrThrow flags absent required field as null', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required()],
      });
      ValidationException? caught;
      try {
        await validator.validateOrThrow(<String, Object?>{});
      } on ValidationException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.errors['name'], isNotEmpty);
    });

    test('two failing fields surface both keys in errors', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required()],
        'email': <ValidationRule>[Email()],
      });
      ValidationException? caught;
      try {
        await validator.validateOrThrow(<String, Object?>{
          'name': '',
          'email': 'bad',
        });
      } on ValidationException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.errors.keys, containsAll(<String>['name', 'email']));
    });

    test('one field with two failing rules yields two entries', () async {
      const validator = Validator(<String, List<ValidationRule>>{
        'name': <ValidationRule>[Required(), MinLength(5)],
      });
      final errors = await validator.validate(<String, Object?>{'name': ''});
      expect(errors['name'], hasLength(2));
    });
  });

  group('validateModel', () {
    test('throws ValidationException when the Validatable is invalid', () {
      const user = _FakeUser(email: 'bad', name: '');
      expect(
        () => validateModel(user),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors.keys,
            'errors.keys',
            containsAll(<String>['email', 'name']),
          ),
        ),
      );
    });

    test('returns normally when the Validatable is valid', () async {
      const user = _FakeUser(email: 'a@b.com', name: 'Ada');
      await validateModel(user);
    });

    test('Validatable exposes tableName and primaryKeyValue', () {
      const user = _FakeUser(email: 'a@b.com', name: 'Ada', id: 'u-1');
      expect(user.tableName, 'users');
      expect(user.primaryKeyValue, 'u-1');
    });
  });
}
