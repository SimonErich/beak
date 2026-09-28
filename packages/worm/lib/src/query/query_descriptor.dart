/// Immutable descriptor for SELECT queries.
library;

import 'join_clause.dart';
import 'predicate_tree.dart';
import 'sort_clause.dart';

/// Describes a SELECT query without any
/// database-specific syntax.
///
/// Produced by the query builder and compiled into
/// native queries by adapters.
final class QueryDescriptor {
  /// Creates a [QueryDescriptor].
  const QueryDescriptor({
    required this.table,
    this.tableAlias,
    this.columns = const <String>[],
    this.where,
    this.orderBy = const <SortClause>[],
    this.limit,
    this.offset,
    this.distinct = false,
    this.joins = const <JoinClause>[],
    this.groupBy = const <String>[],
    this.having = const <HavingClause>[],
  });

  /// The target table name.
  final String table;

  /// Optional SQL table alias, also used for correlated in-memory predicates.
  final String? tableAlias;

  /// Columns to project. Empty means all columns.
  final List<String> columns;

  /// Optional WHERE predicate tree.
  final PredicateTree? where;

  /// ORDER BY clauses.
  final List<SortClause> orderBy;

  /// Maximum number of rows to return.
  final int? limit;

  /// Number of rows to skip.
  final int? offset;

  /// Whether to return only distinct rows.
  final bool distinct;

  /// SQL JOIN clauses (SQL adapters only).
  final List<JoinClause> joins;

  /// GROUP BY columns (SQL adapters only).
  final List<String> groupBy;

  /// HAVING conditions applied after grouping (SQL adapters only).
  final List<HavingClause> having;

  /// Returns a copy of this descriptor with selected
  /// fields overridden. Pass `clearWhere: true` to
  /// reset [where] back to `null`.
  QueryDescriptor copyWith({
    String? table,
    String? tableAlias,
    List<String>? columns,
    PredicateTree? where,
    bool clearWhere = false,
    List<SortClause>? orderBy,
    int? limit,
    int? offset,
    bool? distinct,
    List<JoinClause>? joins,
    List<String>? groupBy,
    List<HavingClause>? having,
  }) => QueryDescriptor(
    table: table ?? this.table,
    tableAlias: tableAlias ?? this.tableAlias,
    columns: columns ?? this.columns,
    where: clearWhere ? null : (where ?? this.where),
    orderBy: orderBy ?? this.orderBy,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
    distinct: distinct ?? this.distinct,
    joins: joins ?? this.joins,
    groupBy: groupBy ?? this.groupBy,
    having: having ?? this.having,
  );

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'query',
    'table': table,
    if (tableAlias != null) 'tableAlias': tableAlias,
    if (columns.isNotEmpty) 'columns': columns,
    if (where != null) 'where': where!.toMap(),
    if (joins.isNotEmpty)
      'joins': <Map<String, Object?>>[for (final j in joins) j.toMap()],
    if (groupBy.isNotEmpty) 'groupBy': groupBy,
    if (having.isNotEmpty)
      'having': <Map<String, Object?>>[for (final h in having) h.toMap()],
    if (orderBy.isNotEmpty)
      'orderBy': <Map<String, Object?>>[
        for (final clause in orderBy) clause.toMap(),
      ],
    if (limit != null) 'limit': limit,
    if (offset != null) 'offset': offset,
    if (distinct) 'distinct': distinct,
  };
}
