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
    this.escape,
  }) : assert(
         escape == null || escape.length == 1,
         'escape must be a single character',
       );

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

  /// The character that escapes `%`, `_` and itself in a `like`, `notLike`
  /// or `ilike` pattern, or `null` when the pattern has no escape character.
  ///
  /// With `\` as the escape character, `a\%b` matches the text `a%b` and
  /// nothing else. Adapters state it in the SQL (`ESCAPE '\'`) so the
  /// meaning does not depend on a database's default, which differs.
  final String? escape;

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
    if (escape != null) 'escape': escape,
  };

  Object? _encodeValue(Object? raw) {
    if (raw is (Object?, Object?)) {
      return <String, Object?>{'lower': raw.$1, 'upper': raw.$2};
    }
    return raw;
  }
}
