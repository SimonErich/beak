import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('ValidationException.errors', () {
    test('exposes single-field errors map', () {
      const ex = ValidationException(
        field: 'name',
        rule: 'required',
        message: 'name is required',
      );
      expect(ex.errors, <String, List<String>>{
        'name': <String>['name is required'],
      });
    });

    test('preserves the supplied map via fromMap', () {
      final ex = ValidationException.fromMap(<String, List<String>>{
        'name': <String>['required', 'too short'],
        'email': <String>['malformed'],
      });
      expect(ex.errors['name']!.length, 2);
      expect(ex.errors['email'], <String>['malformed']);
    });

    test('aggregated message reflects every error', () {
      final ex = ValidationException.fromMap(<String, List<String>>{
        'name': <String>['required'],
        'email': <String>['malformed'],
      });
      expect(ex.message, contains('name'));
      expect(ex.message, contains('email'));
    });

    test('errors map is unmodifiable', () {
      final ex = ValidationException.fromMap(<String, List<String>>{
        'name': <String>['required'],
      });
      expect(
        () => ex.errors['name'] = <String>['mutated'],
        throwsUnsupportedError,
      );
    });

    test('single-field errors map is unmodifiable', () {
      const ex = ValidationException(
        field: 'name',
        rule: 'required',
        message: 'name is required',
      );
      expect(
        () => ex.errors['name'] = <String>['mutated'],
        throwsUnsupportedError,
      );
      expect(() => ex.errors['name']!.add('mutated'), throwsUnsupportedError);
    });
  });
}
