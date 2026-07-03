import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/json_support.dart';

/// One global-search match on the wire: which record of which model
/// matched, and how to present it.
///
/// The backend's search endpoint produces hits; the frontend's search box
/// consumes them — both through this shared, losslessly serializable type.
@immutable
final class BeakSearchHit {
  /// Creates a search hit.
  const BeakSearchHit({
    required this.table,
    required this.id,
    required this.displayLabel,
    required this.matchedColumnKey,
  });

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakSearchHit fromJson(Map<String, Object?> json) {
    const context = 'BeakSearchHit';
    return BeakSearchHit(
      table: requireJsonString(json, 'table', context),
      id: switch (requireJsonKey(json, 'id', context)) {
        final int id => id,
        final String id => id,
        final Object? other => throw BeakConfigurationException(
          '$context JSON key "id" must be an integer or string, got $other.',
        ),
      },
      displayLabel: requireJsonString(json, 'displayLabel', context),
      matchedColumnKey: requireJsonString(json, 'matchedColumnKey', context),
    );
  }

  /// Table of the matching model.
  final String table;

  /// Primary key of the matching record.
  final Object id;

  /// The record's display-column value, for rendering the hit.
  final String displayLabel;

  /// Key of the searchable column the term matched (the first one, when
  /// several matched).
  final String matchedColumnKey;

  /// This hit as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'table': table,
    'id': id,
    'displayLabel': displayLabel,
    'matchedColumnKey': matchedColumnKey,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakSearchHit &&
      other.table == table &&
      other.id == id &&
      other.displayLabel == displayLabel &&
      other.matchedColumnKey == matchedColumnKey;

  @override
  int get hashCode => Object.hash(table, id, displayLabel, matchedColumnKey);

  @override
  String toString() => 'BeakSearchHit($table/$id: $displayLabel)';
}
