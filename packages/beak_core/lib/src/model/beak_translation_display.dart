import 'package:meta/meta.dart';

import '../localization/beak_labels.dart';
import '../query/beak_record.dart';

/// A display taken from a record's translation rows.
///
/// Use it when the record has no text column of its own: the picker or link
/// reads the row whose locale is [BeakLabels.language], then falls back to the
/// first translation so a missing locale still shows something.
@immutable
final class BeakTranslationDisplay {
  /// Creates a display specification for a translation relation.
  const BeakTranslationDisplay({
    required this.relationKey,
    required this.columnKey,
    this.localeKey = 'locale',
  });

  /// The relation holding the translation rows.
  final String relationKey;

  /// The translation column with the text to show.
  final String columnKey;

  /// The translation column holding the locale code.
  final String localeKey;

  /// The label of [record] in the panel's language, or an empty string.
  String labelOf(BeakRecord record) {
    final rows = record.relations[relationKey] ?? const [];
    if (rows.isEmpty) return '';
    final language = BeakLabels.language;
    BeakRecord selected = rows.first;
    for (final row in rows) {
      if (row[localeKey]?.raw == language) {
        selected = row;
        break;
      }
    }
    return selected[columnKey]?.raw?.toString() ?? '';
  }
}
