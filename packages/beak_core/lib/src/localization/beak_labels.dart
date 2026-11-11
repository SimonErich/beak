import 'package:meta/meta.dart';

/// The language a panel shows its labels in.
///
/// Models, columns, relationships and enum values carry their labels in every
/// language the project's label files declare (`labels:` in `beak.yaml`,
/// written by `beak generate` and `beak prepare`). The panel sets [language]
/// from the locale of its `Localizations`, so every table header, input,
/// filter and export reads the same language without being passed it:
///
/// ```dart
/// const email = BeakStringColumn(
///   key: 'email',
///   label: 'Email',
///   translations: {'de': 'E-Mail', 'en': 'Email'},
/// );
///
/// BeakLabels.language = 'de';
/// email.label; // 'E-Mail'
/// ```
///
/// A label given where a field is placed, such as `inputText(label: ...)`,
/// always wins over these.
abstract final class BeakLabels {
  /// The language code labels resolve in, such as `de`.
  ///
  /// `null` keeps every declared default label. The panel sets it from its
  /// locale; assign it directly only in a test or for a server request.
  static String? language;

  /// The entry of [translations] for [language], or [fallback].
  static String pick(Map<String, String> translations, String fallback) =>
      translations[language] ?? fallback;

  /// The entry of [translations] for [language], or `null`.
  static String? pickOrNull(Map<String, String> translations) =>
      translations[language];
}

/// What a model and its commands are called, in each language.
///
/// Every map is keyed by language code. `beak generate` and `beak prepare`
/// write one for each model from the project's label files:
///
/// ```dart
/// @override
/// BeakModelLabels get labels => const BeakModelLabels(
///   one: {'de': 'Bestellung', 'en': 'Order'},
///   other: {'de': 'Bestellungen', 'en': 'Orders'},
///   actions: {'cancel': {'de': 'Stornieren', 'en': 'Cancel'}},
/// );
/// ```
@immutable
final class BeakModelLabels {
  /// Creates a model's labels.
  const BeakModelLabels({
    this.one = const {},
    this.other = const {},
    this.actions = const {},
    this.actionDescriptions = const {},
  });

  /// What one record is called.
  final Map<String, String> one;

  /// What several records are called.
  final Map<String, String> other;

  /// Command labels, by command name.
  final Map<String, Map<String, String>> actions;

  /// Command descriptions, by command name.
  final Map<String, Map<String, String>> actionDescriptions;
}
