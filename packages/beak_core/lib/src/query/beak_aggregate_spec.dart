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
/// Application code asks the model for one — `count`, `sum` and `avg` on a
/// generated `XModel` — so the table comes from the model and the filter from
/// its field references, never key strings. The backend decodes the spec with
/// [fromJson] and translates it to the ORM.
///
/// ```dart
/// const products = ProductModel();
///
/// // "How many products can be sold?"
/// final sellable = products.count(filter: ProductModel.active.eq(true));
///
/// // "What is the average product price?"
/// final averagePrice = products.avg(ProductModel.price);
/// ```
///
/// The named constructors are what those methods call, and
/// [BeakAggregateSpec.forKey] is the wire-level path for decoders and
/// data-source adapters.
@immutable
final class BeakAggregateSpec {
  /// Counts the rows of [table] matching [filter].
  const BeakAggregateSpec.count({
    required this.table,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.count,
       _column = null,
       _columnKey = null;

  /// Sums [column] over the rows of [table] matching [filter].
  const BeakAggregateSpec.sum({
    required this.table,
    required BeakColumn column,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.sum,
       _column = column,
       _columnKey = null;

  /// Averages [column] over the rows of [table] matching [filter].
  const BeakAggregateSpec.avg({
    required this.table,
    required BeakColumn column,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.avg,
       _column = column,
       _columnKey = null;

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
    required String? columnKey,
    required this.filter,
    required this.withTrashed,
  }) : _column = null,
       _columnKey = columnKey;

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

  /// The aggregated column, when the spec was built from a column constant.
  ///
  /// Held rather than reduced to its key so [sum] and [avg] can be `const`,
  /// which is what lets a whole screen — metrics included — be one const
  /// expression.
  final BeakColumn? _column;

  final String? _columnKey;

  /// Key of the aggregated column; `null` iff [function] is
  /// [BeakAggregateFunction.count].
  String? get columnKey => _columnKey ?? _column?.key;

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
