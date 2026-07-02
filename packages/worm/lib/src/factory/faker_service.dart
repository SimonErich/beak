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

  /// The underlying `faker_dart` instance for non-seeded
  /// access to the full library API.
  Faker get raw => _faker;

  /// Re-initializes the internal pseudo-random generator.
  ///
  /// Once seeded, deterministic helpers like [name] and
  /// [email] return the same sequence of values across
  /// runs that share the same [value].
  void seed(int value) {
    _random = Random(value);
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
  /// `firstname.lastname@domain`.
  String email() {
    final user = '${firstName().toLowerCase()}.${lastName().toLowerCase()}';
    return '$user@${_pick(_domains)}';
  }

  /// A North American style phone number.
  String phoneNumber() {
    final area = 200 + _random.nextInt(800);
    final prefix = 100 + _random.nextInt(900);
    final line = _random.nextInt(10000).toString().padLeft(4, '0');
    return '($area) $prefix-$line';
  }

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

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
}
