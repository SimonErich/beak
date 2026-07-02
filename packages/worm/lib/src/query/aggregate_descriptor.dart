/// Descriptor for aggregate queries.
library;

import 'predicate_tree.dart';

/// Kinds of aggregations supported.
enum AggregateFunction {
  /// Row count.
  count,

  /// Numeric sum.
  sum,

  /// Numeric average.
  avg,

  /// Minimum value.
  min,

  /// Maximum value.
  max,
}

/// Immutable description of an aggregate query.
final class AggregateDescriptor {
  /// Creates an [AggregateDescriptor].
  const AggregateDescriptor({
    required this.table,
    required this.function,
    this.column,
    this.where,
    this.groupBy,
  });

  /// Convenience for `COUNT(*)`.
  const AggregateDescriptor.count({
    required String table,
    String? column,
    PredicateTree? where,
    String? groupBy,
  }) : this(
         table: table,
         function: AggregateFunction.count,
         column: column,
         where: where,
         groupBy: groupBy,
       );

  /// Target table name.
  final String table;

  /// The aggregation to perform.
  final AggregateFunction function;

  /// Column to aggregate over. `null` for
  /// `COUNT(*)`-style aggregations.
  final String? column;

  /// Optional WHERE predicate tree.
  final PredicateTree? where;

  /// Optional grouping column. When set, the aggregate is computed
  /// per distinct value of this column (`GROUP BY`), and the adapter
  /// returns one value per group instead of a single scalar — used by
  /// the eager loader to roll up `withCount` / `withSum` across many
  /// parents in one query.
  final String? groupBy;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'aggregate',
    'table': table,
    'function': function.name,
    if (column != null) 'column': column,
    if (where != null) 'where': where!.toMap(),
    if (groupBy != null) 'groupBy': groupBy,
  };
}
