/// Virtual aggregate field access.
library;

import 'package:test/test.dart';
import 'package:worm/src/exception/uninitialized_field_exception.dart';

import '_fixtures.dart';

void main() {
  group('getInjected', () {
    test('throws when the field was never populated', () {
      final model = TestModel(tableNameOverride: 'tests');
      expect(
        () => model.getInjected<int>('postsCount'),
        throwsA(
          isA<UninitializedFieldException>().having(
            (e) => e.field,
            'field',
            'postsCount',
          ),
        ),
      );
    });

    test('returns the value when populated by withCount-style injection', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..injectedFields['postsCount'] = 5;
      expect(model.getInjected<int>('postsCount'), 5);
    });

    test('treats null as "uninitialized" only when the key is absent', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..injectedFields['profileExists'] = null;
      // Key is present; the value just happens to be null. Calling
      // getInjected<bool?> reads null without throwing.
      expect(model.getInjected<bool?>('profileExists'), isNull);
    });

    test('throws when value type is incompatible with the requested type', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..injectedFields['postsCount'] = 'five';
      expect(
        () => model.getInjected<int>('postsCount'),
        throwsA(isA<UninitializedFieldException>()),
      );
    });
  });
}
