import '../columns/beak_semantic_values.dart';
import '../common/beak_exception.dart';
import '../common/json_support.dart';
import '../model/beak_field_ref.dart';
import 'beak_filter.dart';
import 'beak_query_spec.dart';
import 'beak_value.dart';

/// A server-side summary measure. Amounts retain their stored exact units.
///
/// A measure is declared once and referenced by object: the row it produces is
/// read with [BeakSummaryRow.valueOf], and a display binds to the same
/// instance. Its [key] only names the value on the wire.
final class BeakSummaryMeasure {
  /// Counts records, including records whose grouped value is null.
  // --8<-- [start:BeakSummaryMeasure]
  const BeakSummaryMeasure.count(this.key, {this.filter})
    : columnKey = null,
      scale = null;

  /// Sums a numeric field of the summarized model, with zero for an empty
  /// population.
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship.
  BeakSummaryMeasure.sum(
    this.key, {
    required BeakScalarField<num> field,
    this.filter,
  }) : columnKey = field.rootKey,
       scale = null;

  /// Sums an exact-decimal or money field of the summarized model, with zero
  /// for an empty population.
  ///
  /// The wire form is the same as [BeakSummaryMeasure.sum]'s (stored integer
  /// units are added, which is exact); the difference is on this side of the
  /// wire, where the row reads the total back as an amount with
  /// [BeakSummaryRow.decimalOf].
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship or one without exact-decimal or money semantics.
  BeakSummaryMeasure.sumDecimal(
    this.key, {
    required BeakScalarField<BeakDecimal> field,
    this.filter,
  }) : columnKey = field.exactColumn.key,
       scale = field.scale;

  /// Wire constructor. A null column denotes a count.
  const BeakSummaryMeasure.forKey(this.key, {this.columnKey, this.filter})
    : scale = null;
  // --8<-- [end:BeakSummaryMeasure]

  /// Stable result key, independent of a translated display label.
  final String key;

  /// Numeric storage column to sum, or null to count.
  final String? columnKey;

  /// Decimal places of the summed amount for a measure built with
  /// [BeakSummaryMeasure.sumDecimal], otherwise null.
  ///
  /// Client-side only: it never travels, because the row is read with the
  /// same measure instance that asked for it.
  final int? scale;

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
    final String? columnKey = switch (json['column']) {
      null => null,
      final String value => value,
      _ => throw const BeakConfigurationException(
        'Summary column must be a string.',
      ),
    };
    final Map<String, Object?>? filter = optionalJsonMap(
      json,
      'filter',
      'BeakSummaryMeasure',
    );
    return BeakSummaryMeasure.forKey(
      requireJsonString(json, 'key', 'BeakSummaryMeasure'),
      columnKey: columnKey,
      filter: filter == null ? null : BeakFilter.fromJson(filter),
    );
  }
}

/// A bounded grouped query over the entire matching population, never a page.
///
/// Application code asks its model for one —
/// `const OrderModel().summary(groupBy: OrderModel.status, measures: [...])` —
/// so the table and the group key come from typed fields.
///
/// Calendar-date columns group by their canonical calendar date; instant
/// columns group by exact instant. Bucketing instants implicitly in the browser
/// timezone is deliberately not part of this contract.
final class BeakSummarySpec {
  /// Creates a summary from raw keys, the wire-level path for decoders and
  /// data-source adapters.
  ///
  /// Application code calls `model.summary(...)`, which fills in the table and
  /// the group key from typed fields.
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
    final (String? groupByKey, int limit) = switch ((
      json['groupBy'],
      json['limit'],
    )) {
      (final String? group, final int? limit) => (group, limit ?? 100),
      _ => throw const BeakConfigurationException(
        'Invalid summary group or limit type.',
      ),
    };
    return BeakSummarySpec.forKeys(
      table: query.table,
      groupByKey: groupByKey,
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

  /// Values keyed by each measure's stable key: the wire form of the row.
  ///
  /// Application code reads a value with [valueOf].
  final Map<String, num> values;

  /// The value computed for [measure], or null when the response has none.
  num? valueOf(BeakSummaryMeasure measure) => values[measure.key];

  /// The exact amount computed for a [BeakSummaryMeasure.sumDecimal]
  /// [measure], or null when the response has none.
  ///
  /// Throws a [BeakConfigurationException] for a measure that is not a
  /// decimal sum, and for a value that is not a whole number of stored units
  /// (this never rounds money).
  BeakDecimal? decimalOf(BeakSummaryMeasure measure) {
    final int scale =
        measure.scale ??
        (throw BeakConfigurationException(
          'Measure "${measure.key}" is not a decimal sum; read it with '
          'valueOf.',
        ));
    final num? units = values[measure.key];
    if (units == null) return null;
    return BeakDecimal.tryFromUnits(units, scale: scale) ??
        (throw BeakConfigurationException(
          'Measure "${measure.key}" holds $units, which is not a whole '
          'number of stored units.',
        ));
  }

  /// Encodes this row.
  Map<String, Object?> toJson() => {'group': group.toJson(), 'values': values};

  /// Strictly decodes this row.
  factory BeakSummaryRow.fromJson(Map<String, Object?> json) {
    final raw = requireJsonMap(json, 'values', 'BeakSummaryRow');
    final values = <String, num>{
      for (final MapEntry(:key, :value) in raw.entries)
        key: switch (value) {
          final num number => number,
          _ => throw const BeakConfigurationException(
            'Summary values must be numeric.',
          ),
        },
    };
    return BeakSummaryRow(
      group: BeakValue.fromJson(
        requireJsonKey(json, 'group', 'BeakSummaryRow'),
      ),
      values: values,
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
