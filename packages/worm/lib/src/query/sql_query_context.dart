/// Adapter-context surface exposed via
/// `QueryBuilder.sql(...)`.
library;

import '../model/model.dart';
import 'field.dart';
import 'join_clause.dart';
import 'operator.dart';
import 'predicate_tree.dart';
import 'query_builder.dart';
import 'query_descriptor.dart';

/// SQL-flavoured chainable surface returned by
/// `QueryBuilder.sql(...)`.
///
/// Adds SQL-only constructs — raw fragments, joins, grouping, and
/// having — that only make sense against a relational backend.
/// Construction is gated by `QueryBuilder.sql` which throws
/// `AdapterMismatchException` for non-SQL adapters, so callers can
/// rely on a SQL-capable adapter.
///
/// Performance / correctness note: a [join] without a projection
/// compiles to `SELECT *`, which flattens both tables' columns into
/// one row and collides same-named columns (e.g. both `id`s). Pair
/// joins with `.select([...])` to project the columns you need. For
/// loading related rows into typed models, prefer the joinless
/// `withRelations` eager-load path — it batches into a constant number
/// of queries and hydrates each side cleanly.
final class SqlQueryContext<T extends Model> {
  /// Creates a [SqlQueryContext] wrapping [_builder].
  const SqlQueryContext(this._builder);

  final QueryBuilder<T> _builder;

  /// The underlying builder.
  QueryBuilder<T> get builder => _builder;

  /// Append a raw SQL fragment to the WHERE tree.
  SqlQueryContext<T> whereRaw(
    String sql, {
    List<Object?> parameters = const <Object?>[],
  }) =>
      SqlQueryContext<T>(_builder.where(RawNode(sql, parameters: parameters)));

  /// Add an `INNER JOIN <table> ON <left> = <right>`.
  SqlQueryContext<T> join(
    String table,
    Field<Object?> left,
    Field<Object?> right,
  ) => _addJoin(JoinKind.inner, table, left, right);

  /// Add a `LEFT JOIN <table> ON <left> = <right>`.
  SqlQueryContext<T> leftJoin(
    String table,
    Field<Object?> left,
    Field<Object?> right,
  ) => _addJoin(JoinKind.left, table, left, right);

  /// Group results by [fields].
  SqlQueryContext<T> groupBy(List<Field<Object?>> fields) => _next(
    _builder.descriptor.copyWith(
      groupBy: <String>[
        ..._builder.descriptor.groupBy,
        for (final f in fields) f.toString(),
      ],
    ),
  );

  /// Filter grouped results: `HAVING <expression> <operator> <value>`.
  ///
  /// [expression] is a raw aggregate, e.g. `'COUNT(*)'` or
  /// `'SUM(views)'`.
  SqlQueryContext<T> having(
    String expression,
    Operator operator,
    Object? value,
  ) => _next(
    _builder.descriptor.copyWith(
      having: <HavingClause>[
        ..._builder.descriptor.having,
        HavingClause(expression: expression, operator: operator, value: value),
      ],
    ),
  );

  SqlQueryContext<T> _addJoin(
    JoinKind kind,
    String table,
    Field<Object?> left,
    Field<Object?> right,
  ) => _next(
    _builder.descriptor.copyWith(
      joins: <JoinClause>[
        ..._builder.descriptor.joins,
        JoinClause(
          kind: kind,
          table: table,
          leftColumn: left.toString(),
          rightColumn: right.toString(),
        ),
      ],
    ),
  );

  SqlQueryContext<T> _next(QueryDescriptor descriptor) =>
      SqlQueryContext<T>(_builder.withDescriptor(descriptor));
}
