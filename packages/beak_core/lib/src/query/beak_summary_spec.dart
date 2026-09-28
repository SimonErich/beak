import '../columns/beak_column.dart';
import '../common/beak_exception.dart';
import '../common/json_support.dart';
import 'beak_filter.dart';
import 'beak_query_spec.dart';
import 'beak_value.dart';

/// A server-side summary measure. Amounts retain their stored exact units.
final class BeakSummaryMeasure {
  /// Counts records, including records whose grouped value is null.
  const BeakSummaryMeasure.count(this.key, {this.filter}) : columnKey = null;

  /// Sums a numeric column, with zero for an empty population.
  BeakSummaryMeasure.sum(this.key, {required BeakColumn column, this.filter})
    : columnKey = column.key;

  /// Wire constructor. A null column denotes a count.
  const BeakSummaryMeasure.forKey(this.key, {this.columnKey, this.filter});

  /// Stable result key, independent of a translated display label.
  final String key;

  /// Numeric storage column to sum, or null to count.
  final String? columnKey;

  /// Additional predicate intersected with the summary's shared population.
  final BeakFilter? filter;

  /// Encodes the measure without presentation metadata.
  Map<String, Object?> toJson() => {
    'key': key,
    'column': columnKey,
    if (filter != null) 'filter': filter!.toJson(),
  };

  /// Strictly decodes a measure.
  factory BeakSummaryMeasure.fromJson(Map<String, Object?> json) {
    final column = json['column'];
    if (column != null && column is! String) {
      throw const BeakConfigurationException(
        'Summary column must be a string.',
      );
    }
    return BeakSummaryMeasure.forKey(
      requireJsonString(json, 'key', 'BeakSummaryMeasure'),
      columnKey: column as String?,
      filter: json['filter'] == null
          ? null
          : BeakFilter.fromJson(
              requireJsonMap(json, 'filter', 'BeakSummaryMeasure'),
            ),
    );
  }
}

/// A bounded grouped query over the entire matching population, never a page.
///
/// Calendar-date columns group by their canonical calendar date; instant
/// columns group by exact instant. Bucketing instants implicitly in the browser
/// timezone is deliberately not part of this contract.
final class BeakSummarySpec {
  /// Creates a summary using generated column metadata.
  BeakSummarySpec({
    required String table,
    BeakColumn? groupBy,
    required List<BeakSummaryMeasure> measures,
    BeakFilter? filter,
    BeakSearch? search,
    int limit = 100,
    bool withTrashed = false,
  }) : this.forKeys(
         table: table,
         groupByKey: groupBy?.key,
         measures: measures,
         filter: filter,
         search: search,
         limit: limit,
         withTrashed: withTrashed,
       );

  /// Wire constructor; applications normally use [BeakSummarySpec].
  BeakSummarySpec.forKeys({
    required this.table,
    this.groupByKey,
    required List<BeakSummaryMeasure> measures,
    this.filter,
    this.search,
    this.limit = 100,
    this.withTrashed = false,
  }) : measures = List.unmodifiable(measures) {
    if (table.isEmpty || groupByKey == '' || limit < 1 || limit > 500) {
      throw const BeakConfigurationException(
        'Invalid summary table, group, or limit (1–500).',
      );
    }
    final keys = <String>{};
    if (measures.isEmpty ||
        measures.length > 8 ||
        measures.any(
          (measure) =>
              measure.key.isEmpty ||
              measure.key.length > 80 ||
              measure.columnKey == '' ||
              !keys.add(measure.key),
        )) {
      throw const BeakConfigurationException(
        'A summary needs 1–8 uniquely named measures.',
      );
    }
  }

  /// Target model table.
  final String table;

  /// Scalar storage field; null requests a single total row.
  final String? groupByKey;

  /// Ordered measures, independently named.
  final List<BeakSummaryMeasure> measures;

  /// Predicate shared with the visible list or explicitly defined cohort.
  final BeakFilter? filter;

  /// The same typed search used by regular queries.
  final BeakSearch? search;

  /// Maximum groups in the response. Overflow is reported explicitly.
  final int limit;

  /// Whether soft-deleted records participate.
  final bool withTrashed;

  /// Replaces the population while retaining the summary definition.
  BeakSummarySpec withQuery(BeakQuerySpec query) {
    if (query.table != table) {
      throw const BeakConfigurationException(
        'Summary and query tables differ.',
      );
    }
    return BeakSummarySpec.forKeys(
      table: table,
      groupByKey: groupByKey,
      measures: measures,
      filter: query.filter,
      search: query.search,
      limit: limit,
      withTrashed: query.withTrashed,
    );
  }

  /// Encodes the data-source contract.
  Map<String, Object?> toJson() => {
    'table': table,
    'groupBy': groupByKey,
    'measures': measures.map((measure) => measure.toJson()).toList(),
    'filter': filter?.toJson(),
    'search': search?.toJson(),
    'limit': limit,
    'withTrashed': withTrashed,
  };

  /// Decodes and bounds an untrusted request before execution.
  factory BeakSummarySpec.fromJson(Map<String, Object?> json) {
    final query = BeakQuerySpec.fromJson(json);
    final group = json['groupBy'];
    final limit = json['limit'] ?? 100;
    if ((group != null && group is! String) || limit is! int) {
      throw const BeakConfigurationException(
        'Invalid summary group or limit type.',
      );
    }
    return BeakSummarySpec.forKeys(
      table: query.table,
      groupByKey: group as String?,
      measures: requireJsonMapList(
        json['measures'],
        'measures',
        'BeakSummarySpec',
      ).map(BeakSummaryMeasure.fromJson).toList(),
      filter: query.filter,
      search: query.search,
      limit: limit,
      withTrashed: query.withTrashed,
    );
  }
}

/// One group with named numeric aggregates.
final class BeakSummaryRow {
  /// Captures immutable values. Null is a legitimate grouping value.
  BeakSummaryRow({required this.group, required Map<String, num> values})
    : values = Map.unmodifiable(values) {
    if (values.values.any((value) => !value.isFinite)) {
      throw const BeakConfigurationException('Summary values must be finite.');
    }
  }

  /// Canonical storage representation of the grouping field.
  final BeakValue group;

  /// Values keyed by each measure's stable key.
  final Map<String, num> values;

  /// Encodes this row.
  Map<String, Object?> toJson() => {'group': group.toJson(), 'values': values};

  /// Strictly decodes this row.
  factory BeakSummaryRow.fromJson(Map<String, Object?> json) {
    final raw = requireJsonMap(json, 'values', 'BeakSummaryRow');
    if (raw.values.any((value) => value is! num)) {
      throw const BeakConfigurationException('Summary values must be numeric.');
    }
    return BeakSummaryRow(
      group: BeakValue.fromJson(
        requireJsonKey(json, 'group', 'BeakSummaryRow'),
      ),
      values: {for (final entry in raw.entries) entry.key: entry.value! as num},
    );
  }
}

/// A summary response which never silently disguises an incomplete population.
final class BeakSummaryResult {
  /// Captures bounded rows and explicit overflow.
  BeakSummaryResult({
    required List<BeakSummaryRow> rows,
    this.truncated = false,
  }) : rows = List.unmodifiable(rows);

  /// Stable group order, independent of database iteration order.
  final List<BeakSummaryRow> rows;

  /// More groups exist than the requested limit permits.
  final bool truncated;

  /// Encodes the response.
  Map<String, Object?> toJson() => {
    'rows': rows.map((row) => row.toJson()).toList(),
    'truncated': truncated,
  };

  /// Strictly decodes a response.
  factory BeakSummaryResult.fromJson(Map<String, Object?> json) =>
      BeakSummaryResult(
        rows: requireJsonMapList(
          json['rows'],
          'rows',
          'BeakSummaryResult',
        ).map(BeakSummaryRow.fromJson).toList(),
        truncated: requireJsonBool(json, 'truncated', 'BeakSummaryResult'),
      );
}

/// Optional data-source capability for complete-population summaries.
abstract interface class BeakSummaryDataSource {
  /// Executes the summary; unsupported sources must report that explicitly.
  Future<BeakSummaryResult> summary(BeakSummarySpec spec);
}
