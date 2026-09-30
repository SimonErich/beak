import 'package:test/test.dart';

import '../support/beak_cli_internals.dart';

void main() {
  group('a --fields name', () {
    test('that Dart reserves is refused, with the reason', () {
      // `make:resource` writes the name as a field, and `late final String?
      // class;` is not Dart.
      for (final word in ['class', 'default', 'new', 'in', 'is', 'for']) {
        expect(
          () => BeakFieldSpec.parse('$word:string'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('"$word"'), contains('Dart keyword')),
            ),
          ),
          reason: word,
        );
      }
    });

    test('that Beak adds itself is refused', () {
      // `make:resource` writes `timestamps: true`, and the primary key is
      // implied, so declaring any of these declares the column twice.
      for (final name in ['id', 'created_at', 'updated_at', 'record']) {
        expect(
          () => BeakFieldSpec.parse('$name:string'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('"$name"'),
            ),
          ),
          reason: name,
        );
      }
    });

    test('that only resembles one is accepted', () {
      for (final name in [
        'classroom',
        'default_price',
        'newest',
        'record_id',
      ]) {
        expect(BeakFieldSpec.parse('$name:string').name, name, reason: name);
      }
    });
  });
}
