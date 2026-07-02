/// Comparison operators for query predicates.
library;

/// Comparison operators used in query where
/// clauses.
///
/// Long-form spec names (`equals`, `notEquals`, ...) are exposed
/// as static aliases that resolve to the identical canonical enum
/// instance, so `identical(Operator.equals, Operator.eq)` holds at
/// runtime and `Operator.equals` is interchangeable with
/// `Operator.eq` everywhere.
enum Operator {
  /// Equal to (`=`).
  eq,

  /// Not equal to (`!=`).
  neq,

  /// Greater than (`>`).
  gt,

  /// Greater than or equal to (`>=`).
  gte,

  /// Less than (`<`).
  lt,

  /// Less than or equal to (`<=`).
  lte,

  /// SQL `LIKE` pattern match.
  like,

  /// SQL `NOT LIKE` pattern match.
  notLike,

  /// Case-insensitive `LIKE` pattern match.
  ilike,

  /// SQL `IS NULL` check.
  isNull,

  /// SQL `IS NOT NULL` check.
  isNotNull,

  /// SQL `IN (...)` list membership.
  inList,

  /// SQL `NOT IN (...)` list exclusion.
  notInList,

  /// SQL `BETWEEN` range check.
  between,

  /// SQL `NOT BETWEEN` range exclusion.
  notBetween;

  /// Long-form spec alias for [eq].
  static const Operator equals = eq;

  /// Long-form spec alias for [neq].
  static const Operator notEquals = neq;

  /// Long-form spec alias for [gt].
  static const Operator greaterThan = gt;

  /// Long-form spec alias for [gte].
  static const Operator greaterThanOrEqualTo = gte;

  /// Long-form spec alias for [lt].
  static const Operator lessThan = lt;

  /// Long-form spec alias for [lte].
  static const Operator lessThanOrEqualTo = lte;
}
