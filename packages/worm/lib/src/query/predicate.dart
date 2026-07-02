/// A single WHERE-clause predicate.
library;

import 'operator.dart';

/// A single WHERE-clause predicate.
///
/// Immutable value object consumed by `DatabaseAdapter`
/// implementations. Carries the column name, optional table
/// qualifier, comparison [Operator], and the operand value.
///
/// Predicates compose into a `PredicateTree` via boolean operators
/// on `Field` extensions.
final class Predicate {
  /// Creates a predicate.
  const Predicate({
    required this.fieldName,
    required this.operator,
    this.tableName,
    this.value,
  });

  /// The column being compared.
  final String fieldName;

  /// Optional table qualifier (for joins / multi-table queries).
  final String? tableName;

  /// The comparison operator.
  final Operator operator;

  /// Operand value. For `between`/`notBetween` this
  /// is a `(lower, upper)` record. For `inList`/
  /// `notInList` this is a `List<Object?>`. For
  /// scalar operators this is the right-hand side.
  /// For `isNull`/`isNotNull` this is `null`.
  final Object? value;

  /// Fully qualified field name.
  String get qualifiedName =>
      tableName != null ? '$tableName.$fieldName' : fieldName;

  /// Serializes this predicate to a map for tests
  /// and golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'field': qualifiedName,
    'operator': operator.name,
    if (operator != Operator.isNull && operator != Operator.isNotNull)
      'value': _encodeValue(value),
  };

  Object? _encodeValue(Object? raw) {
    if (raw is (Object?, Object?)) {
      return <String, Object?>{'lower': raw.$1, 'upper': raw.$2};
    }
    return raw;
  }
}
