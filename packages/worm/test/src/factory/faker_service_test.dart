import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  final faker = FakerService.instance;

  setUp(() => faker.seed(42));

  group('determinism', () {
    List<Object> drawAll() => <Object>[
      faker.name(),
      faker.email(),
      faker.phoneNumber(),
      faker.intBetween(1, 1000),
      faker.decimalBetween(0, 500),
      faker.dateBetween(DateTime.utc(2020), DateTime.utc(2026)),
      faker.boolean(),
      faker.element(const <String>['a', 'b', 'c']),
      faker.weighted(const <String, int>{'x': 1, 'y': 3}),
      faker.word(),
      faker.sentence(),
      faker.paragraph(),
      faker.company(),
      faker.jobTitle(),
      faker.city(),
      faker.country().isoCode,
      faker.hexColor(),
      faker.uuid(),
      faker.imageUrl(),
      faker.avatarUrl(),
    ];

    test('the same seed reproduces the same sequence', () {
      faker.seed(7);
      final first = drawAll();
      faker.seed(7);
      final second = drawAll();

      expect(second, first);
    });

    test('the exposed random rides the seeded stream', () {
      faker.seed(11);
      final first = faker.random.nextInt(1 << 20);
      faker.seed(11);
      final second = faker.random.nextInt(1 << 20);

      expect(second, first);
    });
  });

  group('intBetween', () {
    test('stays within the inclusive range', () {
      final values = List<int>.generate(200, (_) => faker.intBetween(3, 5));

      expect(values, everyElement(inInclusiveRange(3, 5)));
      expect(values.toSet(), containsAll(<int>[3, 4, 5]));
    });

    test('collapses when min equals max', () {
      expect(faker.intBetween(9, 9), 9);
    });

    test('rejects an inverted range', () {
      expect(() => faker.intBetween(5, 3), throwsArgumentError);
    });
  });

  group('decimalBetween', () {
    test('stays within range and respects fraction digits', () {
      final values = List<double>.generate(
        200,
        (_) => faker.decimalBetween(10, 20, fractionDigits: 1),
      );

      expect(values, everyElement(inInclusiveRange(10, 20)));
      for (final value in values) {
        expect(value, closeTo((value * 10).roundToDouble() / 10, 1e-9));
      }
    });

    test('rejects an inverted range', () {
      expect(() => faker.decimalBetween(2, 1), throwsArgumentError);
    });
  });

  group('dateBetween', () {
    test('stays within the range', () {
      final start = DateTime.utc(2026, 7, 1);
      final end = DateTime.utc(2026, 7, 31);
      final values = List<DateTime>.generate(
        100,
        (_) => faker.dateBetween(start, end),
      );

      for (final value in values) {
        expect(value.isBefore(start), isFalse);
        expect(value.isAfter(end), isFalse);
      }
    });

    test('rejects an inverted range', () {
      final start = DateTime.utc(2026, 2);
      final end = DateTime.utc(2026);

      expect(() => faker.dateBetween(start, end), throwsArgumentError);
    });
  });

  group('boolean', () {
    test('probability zero never fires', () {
      final values = List<bool>.generate(
        100,
        (_) => faker.boolean(probability: 0),
      );

      expect(values, everyElement(isFalse));
    });

    test('probability one always fires', () {
      final values = List<bool>.generate(
        100,
        (_) => faker.boolean(probability: 1),
      );

      expect(values, everyElement(isTrue));
    });
  });

  group('element', () {
    test('returns a member of the list', () {
      const options = <String>['red', 'green', 'blue'];
      final values = List<String>.generate(50, (_) => faker.element(options));

      expect(values, everyElement(isIn(options)));
    });

    test('rejects an empty list', () {
      expect(() => faker.element(const <int>[]), throwsArgumentError);
    });
  });

  group('weighted', () {
    test('never returns a zero-weight key', () {
      final values = List<String>.generate(
        200,
        (_) => faker.weighted(const <String, int>{'never': 0, 'always': 1}),
      );

      expect(values, everyElement('always'));
    });

    test('favors heavier keys', () {
      final draws = List<String>.generate(
        1000,
        (_) => faker.weighted(const <String, int>{'rare': 1, 'common': 9}),
      );
      final commonCount = draws.where((value) => value == 'common').length;

      expect(commonCount, greaterThan(700));
    });

    test('rejects non-positive weight tables', () {
      expect(
        () => faker.weighted(const <String, int>{'a': 0}),
        throwsArgumentError,
      );
      expect(
        () => faker.weighted(const <String, int>{'a': -1, 'b': 5}),
        throwsArgumentError,
      );
    });
  });

  group('content generators', () {
    test('sentence is capitalized, sized, and terminated', () {
      final sentence = faker.sentence(wordCount: 5);

      expect(sentence, endsWith('.'));
      expect(sentence[0], sentence[0].toUpperCase());
      expect(sentence.split(' '), hasLength(5));
    });

    test('paragraph joins the requested number of sentences', () {
      final paragraph = faker.paragraph(sentenceCount: 4);

      expect('.'.allMatches(paragraph), hasLength(4));
    });

    test('company, jobTitle, city, and word are non-empty', () {
      expect(faker.company(), isNotEmpty);
      expect(faker.jobTitle(), isNotEmpty);
      expect(faker.city(), isNotEmpty);
      expect(faker.word(), isNotEmpty);
    });

    test('country pairs a name with a two-letter ISO code', () {
      final country = faker.country();

      expect(country.name, isNotEmpty);
      expect(country.isoCode, matches(RegExp(r'^[A-Z]{2}$')));
    });

    test('hexColor is a six-digit lowercase hex value', () {
      final values = List<String>.generate(50, (_) => faker.hexColor());

      expect(values, everyElement(matches(RegExp(r'^#[0-9a-f]{6}$'))));
    });

    test('imageUrl embeds the requested dimensions', () {
      expect(faker.imageUrl(width: 320, height: 200), contains('/320/200'));
    });

    test('avatarUrl points at a numbered placeholder portrait', () {
      expect(faker.avatarUrl(), matches(RegExp(r'\?img=\d+$')));
    });
  });

  group('uuid minter', () {
    test('emits version-4 variant-1 shaped ids', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}'
        r'-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final values = List<String>.generate(100, (_) => faker.uuid());

      expect(values, everyElement(matches(pattern)));
    });

    test('does not repeat within a run', () {
      final values = List<String>.generate(500, (_) => faker.uuid());

      expect(values.toSet(), hasLength(500));
    });
  });

  group('email uniqueness', () {
    test('outlasts the bundled name combinations', () {
      final emails = List<String>.generate(300, (_) => faker.email());

      expect(emails.toSet(), hasLength(300));
    });

    test('seed resets the uniqueness ledger', () {
      faker.seed(3);
      final first = faker.email();
      faker.seed(3);
      final second = faker.email();

      expect(second, first);
    });
  });
}
