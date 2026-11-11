import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Exhaustive code map over the sealed hierarchy: adding a subclass without
/// deciding its stable code is a compile-time error here.
String expectedCodeOf(BeakException exception) => switch (exception) {
  BeakValidationException() => 'validation',
  BeakNotFoundException() => 'not_found',
  BeakAuthenticationException() => 'authentication',
  BeakAuthorizationException() => 'authorization',
  BeakConfigurationException() => 'configuration',
  BeakStorageException() => 'storage',
  BeakConflictException() => 'conflict',
  BeakInternalException() => 'internal',
  BeakPayloadTooLargeException() => 'payload_too_large',
  BeakTransportException() => 'transport',
};

void main() {
  const cases = <(BeakException, String)>[
    (BeakValidationException('Validation failed.'), 'Validation failed.'),
    (
      BeakNotFoundException('Product 42 does not exist.'),
      'Product 42 does not exist.',
    ),
    (
      BeakAuthenticationException('Sign in to continue.'),
      'Sign in to continue.',
    ),
    (BeakAuthorizationException('Admins only.'), 'Admins only.'),
    (
      BeakConfigurationException('No storage driver registered.'),
      'No storage driver registered.',
    ),
    (
      BeakStorageException('Upload of avatar.png failed.'),
      'Upload of avatar.png failed.',
    ),
    (BeakConflictException('SKU is already taken.'), 'SKU is already taken.'),
    (BeakInternalException('Internal server error.'), 'Internal server error.'),
    (
      BeakPayloadTooLargeException('The upload is larger than 5 MB.'),
      'The upload is larger than 5 MB.',
    ),
    (
      BeakTransportException('The gateway did not answer.'),
      'The gateway did not answer.',
    ),
  ];

  test('each exception carries its stable code and the given message', () {
    for (final (exception, message) in cases) {
      expect(exception.code, expectedCodeOf(exception));
      expect(exception.message, message);
    }
  });

  test('toString() includes the code and the message', () {
    for (final (exception, message) in cases) {
      final rendered = exception.toString();
      expect(rendered, contains('(${exception.code})'));
      expect(rendered, contains(message));
    }
  });

  test('every exception implements Exception for throw boundaries', () {
    for (final (exception, _) in cases) {
      expect(exception, isA<Exception>());
    }
  });

  test('validation exception aggregates typed errors per field', () {
    const exception = BeakValidationException(
      'Validation failed.',
      fieldErrors: {
        'name': ['Name is required.'],
        'price': ['Must be at least 0.', 'Must be a number.'],
      },
    );
    expect(exception.fieldErrors, hasLength(2));
    expect(exception.fieldErrors['name'], const ['Name is required.']);
    expect(exception.fieldErrors['price'], const [
      'Must be at least 0.',
      'Must be a number.',
    ]);
    expect(exception.toString(), contains('(validation)'));
    expect(exception.toString(), contains('price'));
    expect(exception.toString(), contains('Must be a number.'));
  });

  test('validation exception defaults to no field errors', () {
    const exception = BeakValidationException('Validation failed.');
    expect(exception.fieldErrors, isEmpty);
    expect(exception.toString(), contains('(validation)'));
    expect(exception.toString(), contains('Validation failed.'));
  });

  // --8<-- [start:forCategoryTests]
  group('forCategory', () {
    test('maps each category to its exception type', () {
      expect(
        BeakException.forCategory(BeakErrorCategory.validation, 'Bad.'),
        isA<BeakValidationException>(),
      );
      expect(
        BeakException.forCategory(BeakErrorCategory.notFound, 'Gone.'),
        isA<BeakNotFoundException>(),
      );
      expect(
        BeakException.forCategory(BeakErrorCategory.unauthenticated, 'Who?'),
        isA<BeakAuthenticationException>(),
      );
      expect(
        BeakException.forCategory(BeakErrorCategory.forbidden, 'No.'),
        isA<BeakAuthorizationException>(),
      );
      expect(
        BeakException.forCategory(BeakErrorCategory.conflict, 'Taken.'),
        isA<BeakConflictException>(),
      );
      expect(
        BeakException.forCategory(BeakErrorCategory.unexpected, 'Oops.'),
        isA<BeakInternalException>(),
      );
    });

    test('covers every category and keeps the stable codes', () {
      for (final category in BeakErrorCategory.values) {
        final exception = BeakException.forCategory(category, 'Message.');
        expect(exception.message, 'Message.');
        expect(exception.code, expectedCodeOf(exception));
      }
    });

    test('a validation failure attaches the message to the given field', () {
      final exception = BeakException.forCategory(
        BeakErrorCategory.validation,
        'Already taken.',
        field: 'sku',
      );
      expect(
        exception,
        isA<BeakValidationException>().having(
          (error) => error.fieldErrors,
          'fieldErrors',
          {
            'sku': ['Already taken.'],
          },
        ),
      );
    });

    test('a validation failure without a field has no field errors', () {
      final exception = BeakException.forCategory(
        BeakErrorCategory.validation,
        'Bad.',
      );
      expect(
        exception,
        isA<BeakValidationException>().having(
          (error) => error.fieldErrors,
          'fieldErrors',
          isEmpty,
        ),
      );
    });

    test('a field on any other category is ignored', () {
      final exception = BeakException.forCategory(
        BeakErrorCategory.conflict,
        'Taken.',
        field: 'sku',
      );
      expect(exception, isA<BeakConflictException>());
      expect(exception.message, 'Taken.');
    });
  });
  // --8<-- [end:forCategoryTests]
}
