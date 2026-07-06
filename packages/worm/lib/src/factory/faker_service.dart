/// Singleton wrapper around `faker_dart` for fixture data.
library;

import 'dart:math';

import 'package:faker_dart/faker_dart.dart';

/// Application-wide source of fake data for factories and
/// seeders.
///
/// Provides:
///
/// - A [seed] method that re-initializes the internal
///   pseudo-random generator so repeated calls produce
///   identical sequences — essential for reproducible
///   tests and seed snapshots.
/// - Locale-aware helpers ([name], [firstName], [lastName],
///   [email], [phoneNumber]) that draw from built-in
///   datasets when seeded, and otherwise delegate to
///   `faker_dart`.
/// - Seedable value generators for volume seeding:
///   [intBetween], [decimalBetween], [dateBetween],
///   [boolean], [element], [weighted], [hexColor], and the
///   deterministic id minter [uuid].
/// - Seedable content generators: [word], [sentence],
///   [paragraph], [company], [jobTitle], [city], [country],
///   [imageUrl], and [avatarUrl].
/// - A [setLocale] method that forwards to the underlying
///   `Faker` instance.
///
/// `faker_dart` does not expose a seedable random source
/// directly, so seeded helpers use an internal [Random]
/// against bundled datasets. The wrapped [raw] instance is
/// exposed for callers that need the full `faker_dart`
/// surface without determinism guarantees.
final class FakerService {
  FakerService._();

  /// Singleton instance.
  static final FakerService instance = FakerService._();

  final Faker _faker = Faker.unique();
  Random _random = Random();
  final Set<String> _issuedEmails = <String>{};

  /// The underlying `faker_dart` instance for non-seeded
  /// access to the full library API.
  Faker get raw => _faker;

  /// The seeded pseudo-random generator behind every
  /// deterministic helper, exposed so seeders can compose
  /// their own values on the same reproducible stream.
  Random get random => _random;

  /// Re-initializes the internal pseudo-random generator
  /// and clears the [email] uniqueness ledger.
  ///
  /// Once seeded, deterministic helpers like [name] and
  /// [email] return the same sequence of values across
  /// runs that share the same [value].
  void seed(int value) {
    _random = Random(value);
    _issuedEmails.clear();
  }

  /// Forwards the locale change to the wrapped `faker_dart`
  /// instance. Locale only affects non-seeded delegations.
  void setLocale(FakerLocaleType locale) => _faker.setLocale(locale);

  /// A full personal name like `"Alice Carter"`.
  String name() => '${firstName()} ${lastName()}';

  /// A personal first name.
  String firstName() => _pick(_firstNames);

  /// A personal last name.
  String lastName() => _pick(_lastNames);

  /// An email address of the form
  /// `firstname.lastname@domain`, unique per seeded run.
  ///
  /// Repeated name draws collide once the bundled datasets
  /// are exhausted, so a numeric suffix is appended to keep
  /// every issued address unique — [seed] resets the
  /// ledger.
  String email() {
    final user = '${firstName().toLowerCase()}.${lastName().toLowerCase()}';
    final domain = _pick(_domains);
    var candidate = '$user@$domain';
    var suffix = 2;
    while (!_issuedEmails.add(candidate)) {
      candidate = '$user$suffix@$domain';
      suffix += 1;
    }
    return candidate;
  }

  /// A North American style phone number.
  String phoneNumber() {
    final area = 200 + _random.nextInt(800);
    final prefix = 100 + _random.nextInt(900);
    final line = _random.nextInt(10000).toString().padLeft(4, '0');
    return '($area) $prefix-$line';
  }

  /// An integer in the inclusive range [min]..[max].
  int intBetween(int min, int max) {
    _requireOrdered(min, max);
    return min + _random.nextInt(max - min + 1);
  }

  /// A double in [min]..[max], rounded to [fractionDigits]
  /// decimal places — convenient for prices and amounts.
  double decimalBetween(num min, num max, {int fractionDigits = 2}) {
    _requireOrdered(min, max);
    final value = min + _random.nextDouble() * (max - min);
    return double.parse(value.toStringAsFixed(fractionDigits));
  }

  /// A moment in the inclusive range [start]..[end].
  DateTime dateBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      throw ArgumentError.value(end, 'end', 'must not precede start');
    }
    final spanInMs = end.difference(start).inMilliseconds;
    final offsetInMs = (_random.nextDouble() * spanInMs).floor();
    return start.add(Duration(milliseconds: offsetInMs));
  }

  /// `true` with the given [probability] (0.0 → never,
  /// 1.0 → always).
  bool boolean({double probability = 0.5}) =>
      _random.nextDouble() < probability;

  /// A uniformly random element of [values].
  T element<T>(List<T> values) {
    if (values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    return _pick(values);
  }

  /// A random key of [weights], where each key's chance is
  /// proportional to its weight. Zero-weight keys are never
  /// returned; iteration order (insertion order) keeps the
  /// draw deterministic under [seed].
  T weighted<T>(Map<T, int> weights) {
    final total = _validatedWeightTotal(weights);
    var roll = _random.nextInt(total);
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) {
        return entry.key;
      }
    }
    throw StateError('unreachable: weights sum to $total');
  }

  /// A single lorem-style word.
  String word() => _pick(_words);

  /// A capitalized lorem-style sentence of [wordCount]
  /// words, ending with a period.
  String sentence({int wordCount = 8}) {
    final words = List<String>.generate(wordCount, (_) => word());
    final first = words.first;
    words[0] = '${first[0].toUpperCase()}${first.substring(1)}';
    return '${words.join(' ')}.';
  }

  /// A paragraph of [sentenceCount] sentences.
  String paragraph({int sentenceCount = 3}) =>
      List<String>.generate(sentenceCount, (_) => sentence()).join(' ');

  /// A company name like `"Klein Labs"`.
  String company() => '${lastName()} ${_pick(_companySuffixes)}';

  /// A job title like `"UX Designer"`.
  String jobTitle() => _pick(_jobTitles);

  /// A city name.
  String city() => _pick(_cities);

  /// A country with its ISO 3166-1 alpha-2 code.
  FakerCountry country() => _pick(_countries);

  /// A lowercase hex color like `"#3fa2c8"`.
  String hexColor() {
    final value = _random.nextInt(0x1000000);
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  /// A deterministic RFC-4122 version-4-shaped UUID minted
  /// from the seeded stream — the id minter for
  /// reproducible seed data and cross-domain references.
  String uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = 0x40 | (bytes[6] & 0x0f);
    bytes[8] = 0x80 | (bytes[8] & 0x3f);
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// A placeholder image URL of [width]×[height] pixels,
  /// deterministic under [seed].
  String imageUrl({int width = 640, int height = 480}) {
    final token = _random.nextInt(100000);
    return 'https://picsum.photos/seed/$token/$width/$height';
  }

  /// A placeholder avatar URL, deterministic under [seed].
  String avatarUrl() =>
      'https://i.pravatar.cc/150?img=${1 + _random.nextInt(70)}';

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

  static void _requireOrdered(num min, num max) {
    if (min > max) {
      throw ArgumentError.value(min, 'min', 'must not exceed max ($max)');
    }
  }

  static int _validatedWeightTotal<T>(Map<T, int> weights) {
    var total = 0;
    for (final weight in weights.values) {
      if (weight < 0) {
        throw ArgumentError.value(weight, 'weights', 'must be >= 0');
      }
      total += weight;
    }
    if (total <= 0) {
      throw ArgumentError.value(weights, 'weights', 'must sum to > 0');
    }
    return total;
  }

  // Datasets are deliberately small and stable so seeded
  // output stays reproducible across releases of the
  // upstream `faker_dart` package.
  static const List<String> _firstNames = <String>[
    'Alice',
    'Bob',
    'Carol',
    'David',
    'Erin',
    'Frank',
    'Grace',
    'Hugo',
    'Iris',
    'Jack',
    'Kara',
    'Liam',
    'Maya',
    'Noah',
    'Olivia',
    'Peter',
  ];

  static const List<String> _lastNames = <String>[
    'Adams',
    'Brown',
    'Carter',
    'Davies',
    'Evans',
    'Foster',
    'Garcia',
    'Hughes',
    'Iverson',
    'Jensen',
    'Klein',
    'Lopez',
    'Mitchell',
    'Nguyen',
    'Owens',
    'Patel',
  ];

  static const List<String> _domains = <String>[
    'example.com',
    'example.org',
    'example.net',
    'mail.dev',
    'test.io',
  ];

  static const List<String> _words = <String>[
    'lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'consectetur',
    'adipiscing',
    'elit',
    'sed',
    'tempor',
    'incididunt',
    'labore',
    'dolore',
    'magna',
    'aliqua',
    'enim',
    'minim',
    'veniam',
    'quis',
    'nostrud',
    'exercitation',
    'ullamco',
    'laboris',
    'nisi',
    'aliquip',
    'commodo',
    'consequat',
    'duis',
    'aute',
    'irure',
    'voluptate',
    'velit',
  ];

  static const List<String> _companySuffixes = <String>[
    'Labs',
    'Systems',
    'Group',
    'Studio',
    'Works',
    'Digital',
    'Ventures',
    'Industries',
  ];

  static const List<String> _jobTitles = <String>[
    'Product Manager',
    'UX Designer',
    'Frontend Developer',
    'Backend Developer',
    'Data Analyst',
    'QA Engineer',
    'DevOps Engineer',
    'Project Lead',
    'Marketing Manager',
    'Sales Executive',
    'Support Specialist',
    'Content Strategist',
    'Finance Controller',
    'HR Generalist',
    'Operations Manager',
    'Solutions Architect',
  ];

  static const List<String> _cities = <String>[
    'Berlin',
    'Vienna',
    'Zurich',
    'New York',
    'London',
    'Paris',
    'Madrid',
    'Rome',
    'Amsterdam',
    'Stockholm',
    'Oslo',
    'Warsaw',
    'Tokyo',
    'Sydney',
    'Toronto',
    'Lisbon',
  ];

  static const List<FakerCountry> _countries = <FakerCountry>[
    FakerCountry(name: 'Germany', isoCode: 'DE'),
    FakerCountry(name: 'Austria', isoCode: 'AT'),
    FakerCountry(name: 'Switzerland', isoCode: 'CH'),
    FakerCountry(name: 'United States', isoCode: 'US'),
    FakerCountry(name: 'United Kingdom', isoCode: 'GB'),
    FakerCountry(name: 'France', isoCode: 'FR'),
    FakerCountry(name: 'Spain', isoCode: 'ES'),
    FakerCountry(name: 'Italy', isoCode: 'IT'),
    FakerCountry(name: 'Netherlands', isoCode: 'NL'),
    FakerCountry(name: 'Sweden', isoCode: 'SE'),
    FakerCountry(name: 'Norway', isoCode: 'NO'),
    FakerCountry(name: 'Poland', isoCode: 'PL'),
    FakerCountry(name: 'Japan', isoCode: 'JP'),
    FakerCountry(name: 'Australia', isoCode: 'AU'),
    FakerCountry(name: 'Canada', isoCode: 'CA'),
    FakerCountry(name: 'Brazil', isoCode: 'BR'),
  ];
}

/// A country entry paired with its ISO 3166-1 alpha-2 code,
/// as returned by [FakerService.country].
final class FakerCountry {
  /// Creates a country entry.
  const FakerCountry({required this.name, required this.isoCode});

  /// English short name, e.g. `"Germany"`.
  final String name;

  /// ISO 3166-1 alpha-2 code, e.g. `"DE"`.
  final String isoCode;
}
