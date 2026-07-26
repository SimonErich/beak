import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../common/beak_exception.dart';
import '../common/json_support.dart';
import 'beak_filter.dart';

/// The aggregate a [BeakAggregateSpec] computes.
enum BeakAggregateFunction {
  /// The number of matching rows.
  count,

  /// The sum of a numeric column over the matching rows.
  sum,

  /// The arithmetic mean of a numeric column over the matching rows.
  avg;

  /// Whether this function aggregates a specific column ([count] does not).
  bool get requiresColumn => this != count;
}

/// A typed, losslessly JSON-serializable description of a single aggregate
/// (for dashboard stats and friends).
///
/// User code builds specs through the typed constructors ([BeakAggregateSpec.count],
/// [BeakAggregateSpec.sum], [BeakAggregateSpec.avg]) using column constants —
/// never key strings; the backend decodes them with [fromJson] and translates
/// them to the ORM.
///
/// ```dart
/// const price = BeakDecimalColumn(key: 'price', label: 'Price');
///
/// // "How many products are in stock?"
/// final activeCount = BeakAggregateSpec.count(
///   table: 'products',
///   filter: BeakFieldFilter(
///     column: const BeakBoolColumn(key: 'in_stock', label: 'In stock'),
///     operator: BeakOperator.eq,
///     value: BeakValue.of(true),
///   ),
/// );
///
/// // "What is the average product price?"
/// final avgPrice = BeakAggregateSpec.avg(table: 'products', column: price);
/// ```
@immutable
final class BeakAggregateSpec {
  /// Counts the rows of [table] matching [filter].
  const BeakAggregateSpec.count({
    required this.table,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.count,
       columnKey = null;

  /// Sums [column] over the rows of [table] matching [filter].
  BeakAggregateSpec.sum({
    required this.table,
    required BeakColumn column,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.sum,
       columnKey = column.key;

  /// Averages [column] over the rows of [table] matching [filter].
  BeakAggregateSpec.avg({
    required this.table,
    required BeakColumn column,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.avg,
       columnKey = column.key;

  /// Creates a spec from raw keys — the deserialization path; prefer the
  /// typed constructors in user code.
  ///
  /// Throws a [BeakConfigurationException] when [table] is empty or when
  /// [columnKey] contradicts what [function] requires.
  factory BeakAggregateSpec.forKey({
    required String table,
    required BeakAggregateFunction function,
    String? columnKey,
    BeakFilter? filter,
    bool withTrashed = false,
  }) {
    if (table.isEmpty) {
      throw const BeakConfigurationException(
        'BeakAggregateSpec.table must not be empty.',
      );
    }
    if (function.requiresColumn && columnKey == null) {
      throw BeakConfigurationException(
        'BeakAggregateFunction.${function.name} requires a column key.',
      );
    }
    if (!function.requiresColumn && columnKey != null) {
      throw BeakConfigurationException(
        'BeakAggregateFunction.${function.name} does not take a column key.',
      );
    }
    return BeakAggregateSpec._(
      table: table,
      function: function,
      columnKey: columnKey,
      filter: filter,
      withTrashed: withTrashed,
    );
  }

  const BeakAggregateSpec._({
    required this.table,
    required this.function,
    required this.columnKey,
    required this.filter,
    required this.withTrashed,
  });

  /// Decodes [json] (produced by [toJson]).
  ///
  /// Only `table` and `function` are required; `column`, `filter` and
  /// `withTrashed` fall back to their defaults when absent, so a request can
  /// send just what it means. [toJson] still writes every key.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakAggregateSpec fromJson(Map<String, Object?> json) {
    final Map<String, Object?>? filterJson = optionalJsonMap(
      json,
      'filter',
      _context,
    );
    return BeakAggregateSpec.forKey(
      table: requireJsonString(json, 'table', _context),
      function: _functionByName(requireJsonString(json, 'function', _context)),
      columnKey: switch (json['column']) {
        null => null,
        final String value => value,
        final Object other => throw BeakConfigurationException(
          '$_context JSON key "column" must be a string or null, got $other.',
        ),
      },
      filter: filterJson == null ? null : BeakFilter.fromJson(filterJson),
      withTrashed: optionalJsonBool(
        json,
        'withTrashed',
        _context,
        orElse: false,
      ),
    );
  }

  static BeakAggregateFunction _functionByName(String name) {
    final BeakAggregateFunction? function = BeakAggregateFunction.values
        .asNameMap()[name];
    if (function == null) {
      throw BeakConfigurationException(
        '"$name" is not a BeakAggregateFunction.',
      );
    }
    return function;
  }

  static const String _context = 'BeakAggregateSpec';

  /// Physical table/collection name of the aggregated model.
  final String table;

  /// The aggregate to compute.
  final BeakAggregateFunction function;

  /// Key of the aggregated column; `null` iff [function] is
  /// [BeakAggregateFunction.count].
  final String? columnKey;

  /// The predicate rows must satisfy to be aggregated, if any.
  final BeakFilter? filter;

  /// Whether soft-deleted rows are included.
  final bool withTrashed;

  /// This spec as a plain JSON-encodable object.
  Map<String, Object?> toJson() => {
    'table': table,
    'function': function.name,
    'column': columnKey,
    'filter': filter?.toJson(),
    'withTrashed': withTrashed,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakAggregateSpec &&
      other.table == table &&
      other.function == function &&
      other.columnKey == columnKey &&
      other.filter == filter &&
      other.withTrashed == withTrashed;

  @override
  int get hashCode =>
      Object.hash(table, function, columnKey, filter, withTrashed);

  @override
  String toString() =>
      'BeakAggregateSpec(${function.name}'
      '${columnKey == null ? '' : '($columnKey)'} on $table)';
}
