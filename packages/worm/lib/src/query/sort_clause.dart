/// A single ORDER BY clause entry.
library;

import 'sort_direction.dart';

/// An individual sort criterion.
///
/// ```dart
/// const sort = SortClause('created_at',
///   direction: SortDirection.desc);
/// ```
final class SortClause {
  /// Creates a [SortClause].
  const SortClause(
    this.fieldName, {
    this.tableName,
    this.direction = SortDirection.asc,
  });

  /// The column to sort by.
  final String fieldName;

  /// Optional table qualifier.
  final String? tableName;

  /// Sort direction.
  final SortDirection direction;

  /// Serializes to a map.
  Map<String, Object?> toMap() => {
    'field': tableName != null ? '$tableName.$fieldName' : fieldName,
    'direction': direction.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortClause &&
          fieldName == other.fieldName &&
          tableName == other.tableName &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(fieldName, tableName, direction);

  @override
  String toString() => 'SortClause(${toMap()})';
}
