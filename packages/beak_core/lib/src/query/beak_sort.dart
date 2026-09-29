import 'package:meta/meta.dart';

import '../common/json_support.dart';

/// A single ordering directive of a query spec.
///
/// Carries the raw [columnKey] for the wire; user code obtains sorts from a
/// typed field — `OrderModel.number.descending()` — or through the spec's
/// `orderBy` builder, never by writing the key.
@immutable
final class BeakSort {
  /// Creates a sort on [columnKey], ascending unless [descending].
  const BeakSort(this.columnKey, {this.descending = false});

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Throws a `BeakConfigurationException` on malformed input.
  static BeakSort fromJson(Map<String, Object?> json) => BeakSort(
    requireJsonString(json, 'column', 'BeakSort'),
    descending: requireJsonBool(json, 'descending', 'BeakSort'),
  );

  /// Key of the column to order by.
  final String columnKey;

  /// Whether to sort descending instead of ascending.
  final bool descending;

  /// This sort as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'column': columnKey,
    'descending': descending,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakSort &&
      other.columnKey == columnKey &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(columnKey, descending);

  @override
  String toString() => 'BeakSort($columnKey ${descending ? 'desc' : 'asc'})';
}
