import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test('the escape character is a backslash', () {
    expect(beakLikeEscape, r'\');
  });

  test('escaping puts a backslash before %, _ and the backslash itself', () {
    expect(beakEscapeLike(r'50%_off\'), r'50\%\_off\\');
  });

  test('text without wildcard characters is unchanged', () {
    expect(beakEscapeLike('plain text'), 'plain text');
    expect(beakEscapeLike(''), '');
  });

  group('beakLikeRegExp', () {
    bool matches(String pattern, String text, {bool caseSensitive = true}) =>
        beakLikeRegExp(pattern, caseSensitive: caseSensitive).hasMatch(text);

    test('% is any run of characters and _ is any one character', () {
      expect(matches('a%c', 'abbbc'), isTrue);
      expect(matches('a%c', 'ac'), isTrue);
      expect(matches('a_c', 'abc'), isTrue);
      expect(matches('a_c', 'ac'), isFalse);
      expect(matches('a%c', 'a\nc'), isTrue);
    });

    test('the whole text has to match', () {
      expect(matches('ab', 'abc'), isFalse);
      expect(matches('bc', 'abc'), isFalse);
      expect(matches('%bc', 'abc'), isTrue);
    });

    test('an escaped % or _ or backslash matches itself', () {
      expect(matches(r'50\%', '50%'), isTrue);
      expect(matches(r'50\%', '500'), isFalse);
      expect(matches(r'a\_b', 'a_b'), isTrue);
      expect(matches(r'a\_b', 'axb'), isFalse);
      expect(matches(r'C:\\temp', r'C:\temp'), isTrue);
    });

    test('a trailing escape character stands for itself', () {
      expect(matches(r'ab\', r'ab\'), isTrue);
      expect(matches(r'ab\', 'ab'), isFalse);
    });

    test('regular expression syntax in the pattern is literal', () {
      expect(matches('a.c', 'abc'), isFalse);
      expect(matches('a.c', 'a.c'), isTrue);
      expect(matches('(x)+', '(x)+'), isTrue);
    });

    test('case sensitivity is a choice', () {
      expect(matches('ABC', 'abc'), isFalse);
      expect(matches('ABC', 'abc', caseSensitive: false), isTrue);
    });

    test('a pattern built with beakEscapeLike matches exactly its text', () {
      const text = r'50%_off\';
      expect(matches('%${beakEscapeLike(text)}%', 'sale: $text!'), isTrue);
      expect(matches(beakEscapeLike(text), '500xoff'), isFalse);
    });
  });
}
