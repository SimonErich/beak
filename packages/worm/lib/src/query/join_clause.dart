/// SQL JOIN, GROUP BY, and HAVING clauses carried by descriptors.
library;

import 'operator.dart';

/// The kind of SQL join rendered for a [JoinClause].
enum JoinKind {
  /// `INNER JOIN`.
  inner('INNER JOIN'),

  /// `LEFT JOIN`.
  left('LEFT JOIN');

  const JoinKind(this.sql);

  /// The SQL keyword for this join kind.
  final String sql;
}

/// An immutable SQL JOIN: `<kind> <table> ON <left> = <right>`.
///
/// SQL-only — produced by `QueryBuilder.sql((q) => q.join(...))` and
/// rendered by SQL adapters; non-SQL adapters reject join-bearing
/// descriptors.
final class JoinClause {
  /// Creates a [JoinClause].
  const JoinClause({
    required this.kind,
    required this.table,
    required this.leftColumn,
    required this.rightColumn,
  });

  /// Inner or left join.
  final JoinKind kind;

  /// The joined table name.
  final String table;

  /// Left-hand column of the `ON` equality (qualified, e.g.
  /// `posts.user_id`).
  final String leftColumn;

  /// Right-hand column of the `ON` equality (qualified, e.g.
  /// `users.id`).
  final String rightColumn;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'kind': kind.name,
    'table': table,
    'left': leftColumn,
    'right': rightColumn,
  };
}

/// An immutable HAVING condition: `<expression> <operator> <value>`.
///
/// [expression] is a raw aggregate expression such as `'COUNT(*)'` or
/// `'SUM(views)'`; SQL-only, paired with GROUP BY. The [value] is
/// parameterized by the adapter, but [expression] is emitted verbatim —
/// it is a developer-authored escape hatch (like `whereRaw`) and must
/// never be built from untrusted input.
final class HavingClause {
  /// Creates a [HavingClause].
  const HavingClause({
    required this.expression,
    required this.operator,
    required this.value,
  });

  /// Aggregate expression, e.g. `'COUNT(*)'`.
  final String expression;

  /// Comparison operator.
  final Operator operator;

  /// Right-hand value of the comparison.
  final Object? value;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'expression': expression,
    'operator': operator.name,
    'value': value,
  };
}
