import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One problem with a project's label files, located by file.
final class BeakLabelIssue {
  /// Describes [message] about the file at [path].
  const BeakLabelIssue(this.path, this.message);

  /// The file the problem is in, relative to the project where known.
  final String path;

  /// What is wrong, and what to do about it.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Thrown when the label files cannot be read as a catalog.
final class BeakLabelCatalogException implements Exception {
  /// Reports every [issues] at once.
  const BeakLabelCatalogException(this.issues);

  /// Each problem found.
  final List<BeakLabelIssue> issues;

  @override
  String toString() => issues.join('\n');
}

/// The model, field, enum and action names of a project, read from ARB files
/// with path keys (`placedOrder.email`), one file per locale.
///
/// Flutter's gen-l10n cannot hold these keys (resource names must be Dart
/// method names), so the files live in their own folder, read by
/// `beak generate` and `beak prepare` instead.
final class BeakLabelCatalog {
  const BeakLabelCatalog._(this.template, this.locales, this._texts);

  /// Reads every `*.arb` file in [directory].
  ///
  /// [template] is the locale whose texts generated models carry as their
  /// default labels; without it, the first locale by name leads.
  static BeakLabelCatalog read(Directory directory, {String? template}) {
    final issues = <BeakLabelIssue>[];
    final texts = <String, Map<String, String>>{};
    final files =
        directory.existsSync()
              ? directory
                    .listSync()
                    .whereType<File>()
                    .where((file) => file.path.endsWith('.arb'))
                    .toList()
              : <File>[]
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = p.basename(file.path);
      final Object? document;
      try {
        document = jsonDecode(file.readAsStringSync());
      } on FormatException catch (error) {
        issues.add(BeakLabelIssue(name, 'is not JSON: ${error.message}'));
        continue;
      }
      if (document is! Map<String, Object?>) {
        issues.add(BeakLabelIssue(name, 'is not a JSON object.'));
        continue;
      }
      final Object? locale = document['@@locale'];
      if (locale is! String || locale.isEmpty) {
        issues.add(BeakLabelIssue(name, 'has no "@@locale".'));
        continue;
      }
      if (texts.containsKey(locale)) {
        issues.add(BeakLabelIssue(name, 'is a second file for "$locale".'));
        continue;
      }
      final entries = <String, String>{};
      for (final MapEntry(:key, :value) in document.entries) {
        if (key.startsWith('@')) continue;
        if (value is! String) {
          issues.add(BeakLabelIssue(name, '"$key" is not a text.'));
          continue;
        }
        if (_isPlural(value) && _pluralOf(value) == null) {
          issues.add(
            BeakLabelIssue(name, '"$key" is a plural without an other{...}.'),
          );
          continue;
        }
        entries[key] = value;
      }
      texts[locale] = entries;
    }
    final sorted = texts.keys.toList()..sort();
    final String? leading = template ?? (sorted.isEmpty ? null : sorted.first);
    if (template != null && !texts.containsKey(template)) {
      issues.add(
        BeakLabelIssue(
          p.basename(directory.path),
          'has no file for the template locale "$template".',
        ),
      );
    }
    if (issues.isNotEmpty) throw BeakLabelCatalogException(issues);
    return BeakLabelCatalog._(leading, [
      ?leading,
      for (final locale in sorted)
        if (locale != leading) locale,
    ], texts);
  }

  /// The locale whose texts are the generated default labels, or `null` for
  /// an empty catalog.
  final String? template;

  /// Every locale, [template] first.
  final List<String> locales;

  final Map<String, Map<String, String>> _texts;

  /// Every key of any locale.
  Set<String> get keys => {for (final texts in _texts.values) ...texts.keys};

  /// The keys [locale] declares.
  Set<String> keysOf(String locale) => _texts[locale]?.keys.toSet() ?? {};

  /// The text of [key] in [locale], or `null`.
  String? text(String locale, String key) => _texts[locale]?[key];

  /// The singular and plural of a model name, from an ICU plural or a plain
  /// text that serves both.
  ({String one, String other})? names(String locale, String key) {
    final String? value = text(locale, key);
    if (value == null) return null;
    return _isPlural(value) ? _pluralOf(value) : (one: value, other: value);
  }

  static bool _isPlural(String value) =>
      RegExp(r'^\{\s*\w+\s*,\s*plural\s*,').hasMatch(value.trim());

  static ({String one, String other})? _pluralOf(String value) {
    final cases = <String, String>{
      for (final match in RegExp(
        r'(=\d+|zero|one|two|few|many|other)\s*\{([^{}]*)\}',
      ).allMatches(value))
        match.group(1)!: match.group(2)!.trim(),
    };
    final String? other = cases['other'];
    if (other == null) return null;
    return (one: cases['one'] ?? cases['=1'] ?? other, other: other);
  }
}
