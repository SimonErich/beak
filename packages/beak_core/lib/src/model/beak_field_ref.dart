import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../columns/beak_semantic.dart';
import '../columns/beak_semantic_values.dart';
import '../data/beak_commit.dart';
import '../data/beak_data_source.dart';
import '../common/beak_exception.dart';
import '../query/beak_aggregate_spec.dart';
import '../query/beak_filter.dart';
import '../query/beak_operator.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_record.dart';
import '../query/beak_relation_load.dart';
import '../query/beak_sort.dart';
import '../query/beak_value.dart';
import '../relations/beak_relationship.dart';
import 'beak_field_value.dart';
import 'beak_model.dart';

/// A model-owned field reference shared by queries, forms, and detail views.
///
/// [path] contains the relationships preceding the terminal [key]. It never
/// loads data: reading an unloaded path returns null.
@immutable
abstract class BeakFieldRef<T extends Object> {
  /// Creates a reference rooted at [model].
  const BeakFieldRef({
    required this.model,
    this.path = const [],
    this.isRequired = false,
  });

  /// Root model that owns the path, used to reject invalid form bindings.
  final BeakModel model;

  /// To-one relationships leading from [model] to the field's owner.
  final List<BeakRelationship> path;

  /// Whether the schema declares a non-nullable value.
  final bool isRequired;

  /// Storage key of the terminal column or relationship.
  String get key;

  /// Default human-readable label.
  String get label;

  /// Relation-qualified storage key used by the query wire contract.
  String get qualifiedKey =>
      [...path.map((relation) => relation.key), key].join('.');

  /// Reads an already-loaded record without network or state side effects.
  T? readFrom(BeakRecord record);

  // --8<-- [start:invalid]
  /// A validation failure attached to this field.
  ///
  /// A server-side rule throws it so the form highlights the field, without
  /// the rule ever spelling a column key:
  ///
  /// ```dart
  /// if (quantity < 1) throw OrderItemModel.quantity.invalid('Order one.');
  /// ```
  BeakValidationException invalid(String message) => BeakValidationException(
    message,
    fieldErrors: {
      key: [message],
    },
  );
  // --8<-- [end:invalid]

  /// Resolves the owner record along an eagerly loaded to-one path.
  BeakRecord? ownerRecord(BeakRecord record) {
    var current = record;
    for (final relation in path) {
      if (relation.cardinality != BeakRelationCardinality.one) {
        throw BeakConfigurationException(
          'Cannot read a scalar through the to-many relation "${relation.key}".',
        );
      }
      final rows = current.relations[relation.key];
      if (rows == null || rows.isEmpty) return null;
      current = rows.first;
    }
    return current;
  }
}

/// A generated, typed scalar reference retaining the existing column metadata.
class BeakScalarField<T extends Object> extends BeakFieldRef<T> {
  /// Creates a scalar reference. Generators match [T] to [column]'s value type.
  const BeakScalarField({
    required super.model,
    required this.column,
    super.path,
    super.isRequired,
  });

  /// Shared model-level presentation and validation metadata.
  final BeakColumn column;

  @override
  String get key => column.key;

  @override
  String get label => column.label;

  @override
  T? readFrom(BeakRecord record) {
    final owner = ownerRecord(record);
    if (owner == null) return null;
    if (column.semantic.hasCodec) {
      return switch (column.semantic.tryDecode(owner[key])) {
        final T value => value,
        _ => null,
      };
    }
    if (column case final BeakJsonColumn json when T != String) {
      return switch (json.readDocument(owner[key])) {
        final T value => value,
        _ => null,
      };
    }
    return switch (column) {
      final BeakTypedColumn<T> typed => typed.readFrom(owner),
      _ => throw BeakConfigurationException(
        'Field "$qualifiedKey" has a column incompatible with $T.',
      ),
    };
  }

  /// Reads a required value, reporting a malformed or absent field precisely.
  T require(BeakRecord record) =>
      readFrom(record) ??
      (throw BeakRecordShapeException(columnKey: key, expectedType: T));

  /// Encodes a typed value into this field's canonical storage representation.
  BeakValue encode(T? value) => beakValueForColumn(column, value);

  /// Pairs this field with [value] for a typed write.
  ///
  /// Pass the pairs to a model's `record`, a save operation or the candidate
  /// graph instead of naming the storage key.
  BeakFieldValue to(T? value) => BeakFieldValue(this, encode(value));

  /// Returns a record with this root field replaced; relation paths are read-only.
  BeakRecord writeTo(BeakRecord record, T? value) {
    if (path.isNotEmpty) {
      throw const BeakConfigurationException(
        'Write through the owning record, not a relation path.',
      );
    }
    return BeakRecord(
      values: {...record.values, key: encode(value)},
      relations: record.relations,
    );
  }

  /// The storage key of this field on its own model.
  ///
  /// Sorting, grouping and aggregating work on a model's own columns, so this
  /// throws a [BeakConfigurationException] for a field reached through a
  /// relationship.
  String get rootKey {
    if (path.isNotEmpty) {
      throw BeakConfigurationException(
        'Field "$qualifiedKey" is reached through a relationship; only a '
        'field of ${model.table} itself can be used here.',
      );
    }
    return key;
  }

  /// Orders results by this root field, smallest value first.
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship.
  BeakSort ascending() => BeakSort(rootKey);

  /// Orders results by this root field, largest value first.
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship.
  BeakSort descending() => BeakSort(rootKey, descending: true);

  /// Equality predicate, with null represented as an explicit null check.
  BeakFilter eq(T? value) =>
      _compare(value == null ? BeakOperator.isNull : BeakOperator.eq, value);

  /// Inequality predicate, with null represented as an explicit null check.
  BeakFilter notEq(T? value) => _compare(
    value == null ? BeakOperator.isNotNull : BeakOperator.neq,
    value,
  );

  BeakFilter _compare(BeakOperator operator, T? value) =>
      BeakFieldFilter.forKey(qualifiedKey, operator, encode(value));
}

// --8<-- [start:BeakNumericFieldPredicates]
/// Ordered comparisons available for numeric field references.
extension BeakNumericFieldPredicates<T extends num> on BeakScalarField<T> {
  /// Matches values greater than [value].
  BeakFilter gt(T value) => _compare(BeakOperator.gt, value);

  /// Matches values greater than or equal to [value].
  BeakFilter gte(T value) => _compare(BeakOperator.gte, value);

  /// Matches values less than [value].
  BeakFilter lt(T value) => _compare(BeakOperator.lt, value);

  /// Matches values less than or equal to [value].
  BeakFilter lte(T value) => _compare(BeakOperator.lte, value);
}
// --8<-- [end:BeakNumericFieldPredicates]

/// Ordered comparisons for exact decimals, dates, times, and durations.
extension BeakComparableFieldPredicates<T extends Comparable<T>>
    on BeakScalarField<T> {
  /// Matches values greater than [value].
  BeakFilter gt(T value) => _compare(BeakOperator.gt, value);

  /// Matches values greater than or equal to [value].
  BeakFilter gte(T value) => _compare(BeakOperator.gte, value);

  /// Matches values less than [value].
  BeakFilter lt(T value) => _compare(BeakOperator.lt, value);

  /// Matches values less than or equal to [value].
  BeakFilter lte(T value) => _compare(BeakOperator.lte, value);
}

/// Exact aggregation for fixed-scale decimal and monetary fields.
extension BeakExactDecimalAggregates on BeakScalarField<BeakDecimal> {
  /// The storage column of this field, verified to be a field of its own
  /// model that carries exact-decimal or money semantics.
  ///
  /// Throws a [BeakConfigurationException] for a field reached through a
  /// relationship and for a column without those semantics.
  BeakColumn get exactColumn {
    final bool isExact = switch (column.semantic.kind) {
      BeakSemanticKind.exactDecimal || BeakSemanticKind.money => true,
      _ => false,
    };
    if (path.isNotEmpty || !isExact) {
      throw BeakConfigurationException(
        'Exact aggregates need a root exact-decimal or money field, but '
        '"$qualifiedKey" is not one.',
      );
    }
    return column;
  }

  /// The number of decimal places this field stores.
  ///
  /// Throws a [BeakConfigurationException] under the same conditions as
  /// [exactColumn].
  int get scale => exactColumn.semantic.scale;

  /// Sums this root field, returning its semantic amount rather than storage units.
  ///
  /// Providers must return an integral, safe-range coefficient. Fractional or
  /// overflowing results fail explicitly; this helper never rounds money.
  Future<BeakDecimal> sum(
    BeakDataSource source, {
    BeakFilter? filter,
    bool withTrashed = false,
  }) async {
    final BeakColumn exact = exactColumn;
    final units = await source.aggregate(
      BeakAggregateSpec.sum(
        table: model.table,
        column: exact,
        filter: filter,
        withTrashed: withTrashed,
      ),
    );
    return BeakDecimal.tryFromUnits(units, scale: exact.semantic.scale) ??
        (throw BeakConfigurationException(
          'SUM of "$qualifiedKey" cannot be represented as exact decimal '
          'units.',
        ));
  }

  /// Averages this root field, returning its semantic amount.
  ///
  /// An average of whole units is rarely whole, so the caller names the
  /// [rounding] the result is brought to the field's scale with. Throws a
  /// [BeakConfigurationException] when the average cannot be represented.
  Future<BeakDecimal> avg(
    BeakDataSource source, {
    required BeakRounding rounding,
    BeakFilter? filter,
    bool withTrashed = false,
  }) async {
    final BeakColumn exact = exactColumn;
    final units = await source.aggregate(
      BeakAggregateSpec.avg(
        table: model.table,
        column: exact,
        filter: filter,
        withTrashed: withTrashed,
      ),
    );
    try {
      return BeakDecimal.fromRoundedUnits(
        units,
        scale: exact.semantic.scale,
        rounding: rounding,
      );
    } on FormatException {
      throw BeakConfigurationException(
        'AVG of "$qualifiedKey" cannot be represented as exact decimal '
        'units.',
      );
    }
  }
}

// --8<-- [start:BeakTextFieldPredicates]
/// Text comparisons available only for string references.
extension BeakTextFieldPredicates on BeakScalarField<String> {
  /// Case-insensitive substring match.
  BeakFilter contains(String value) => _compare(BeakOperator.contains, value);
}
// --8<-- [end:BeakTextFieldPredicates]

/// A typed to-one relationship; generated subclasses add target field paths.
class BeakToOneField extends BeakFieldRef<BeakRecord> {
  /// Creates a reference to a related record.
  const BeakToOneField({
    required super.model,
    required this.relation,
    required this.target,
    super.path,
    super.isRequired,
  });

  /// Relationship metadata, including the foreign key and display convention.
  final BeakRelationship relation;

  /// Related model and its transport metadata.
  final BeakModel target;

  @override
  String get key => relation.key;

  @override
  String get label => relation.label;

  @override
  BeakRecord? readFrom(BeakRecord record) {
    final rows = ownerRecord(record)?.relations[key];
    return rows == null || rows.isEmpty ? null : rows.first;
  }

  /// The eager load that brings this related record along with its root
  /// record, including every relationship on the [path] leading to it.
  BeakRelationLoad get relationLoad {
    var load = BeakRelationLoad(key);
    for (final step in path.reversed) {
      load = BeakRelationLoad(step.key, nested: [load]);
    }
    return load;
  }

  /// Pairs this belongs-to field with the [target] record it should reference.
  ///
  /// [target] may be a draft created earlier in the same save plan. Throws a
  /// [BeakConfigurationException] for another relationship kind, a field
  /// reached through a relationship, or a [target] of another model.
  BeakFieldLink linkTo(BeakRecordRef target) {
    if (relation is! BeakBelongsTo || path.isNotEmpty) {
      throw BeakConfigurationException(
        'Only a root belongs-to field can reference a record; "$qualifiedKey" '
        'is not one.',
      );
    }
    if (target.table != this.target.table) {
      throw BeakConfigurationException(
        'Field "$key" references ${this.target.table}, not ${target.table}.',
      );
    }
    return BeakFieldLink(this, target);
  }

  /// A validation failure keyed by the foreign key that backs this field.
  @override
  BeakValidationException invalid(String message) => BeakValidationException(
    message,
    fieldErrors: {
      switch (relation) {
        BeakBelongsTo(:final foreignKey) => foreignKey,
        _ => key,
      }: [
        message,
      ],
    },
  );

  /// Matches the stored foreign key to a selected record's identity.
  BeakFilter eq(BeakRecord? record) =>
      equalsId(record == null ? null : target.primaryKeyOf(record));

  /// Matches a belongs-to foreign key without requiring a loaded record.
  BeakFilter equalsId(Object? id) {
    final relationship = relation;
    if (relationship is! BeakBelongsTo) {
      throw const BeakConfigurationException(
        'Only belongs-to fields can compare a stored foreign key directly.',
      );
    }
    return BeakFieldFilter.forKey(
      [...path.map((step) => step.key), relationship.foreignKey].join('.'),
      id == null ? BeakOperator.isNull : BeakOperator.eq,
      BeakValue.of(id),
    );
  }

  /// Matches when the related record satisfies [filter].
  ///
  /// Build [filter] from the target model's fields. All of its conditions
  /// apply to the same related record, including on nested paths.
  BeakFilter matches(BeakFilter filter) => _scopeRelatedFilter(this, filter);

  /// A declarative picker source using this relationship's search convention.
  BeakOptionQuery options({String search = '', BeakFilter? filter}) =>
      BeakOptionQuery(
        model: target,
        query: target.query(
          filter: filter,
          search: BeakSearch(search, relation.effectiveSearchColumnKeys),
        ),
      );
}

/// A typed to-many relationship edited through a scoped collection draft.
final class BeakToManyField extends BeakFieldRef<List<BeakRecord>> {
  /// Creates a reference to a related record collection.
  const BeakToManyField({
    required super.model,
    required this.relation,
    required this.target,
    super.path,
    super.isRequired,
  });

  /// Relationship metadata including inverse or pivot keys.
  final BeakRelationship relation;

  /// Model of each related record.
  final BeakModel target;

  @override
  String get key => relation.key;

  @override
  String get label => relation.label;

  @override
  List<BeakRecord>? readFrom(BeakRecord record) =>
      ownerRecord(record)?.relations[key];

  /// Matches when one related record satisfies the complete [filter].
  ///
  /// Use target model fields inside [filter]; grouping here avoids separate
  /// conditions accidentally matching different children of the same parent.
  BeakFilter any(BeakFilter filter) => _scopeRelatedFilter(this, filter);

  /// A rooted search path through this collection to [field].
  ///
  /// Use this descriptor in resource global search sources. A collection has
  /// no single scalar value, so reading this path as a scalar remains invalid.
  BeakScalarField<T> search<T extends Object>(BeakScalarField<T> field) {
    if (field.model.table != target.table) {
      throw BeakConfigurationException(
        'Search field ${field.qualifiedKey} does not belong to ${target.table}.',
      );
    }
    return BeakScalarField<T>(
      model: model,
      column: field.column,
      path: [...path, relation, ...field.path],
      isRequired: field.isRequired,
    );
  }
}

BeakFilter _scopeRelatedFilter(BeakFieldRef<Object> field, BeakFilter filter) {
  BeakFilter scoped = BeakRelationFilter(field.key, filter);
  for (final relation in field.path.reversed) {
    scoped = BeakRelationFilter(relation.key, scoped);
  }
  return scoped;
}

/// Read seam implemented by form sessions; generated draft getters delegate here.
abstract interface class BeakDraftReader {
  /// Reads and observes [field], returning null for an incomplete draft value.
  T? read<T extends Object>(BeakFieldRef<T> field);
}

/// A context-free picker query, executed by the panel's data runtime.
@immutable
final class BeakOptionQuery {
  /// Describes [query] against [model]'s resolved data source.
  const BeakOptionQuery({required this.model, required this.query});

  /// Model whose provider executes the query.
  final BeakModel model;

  /// Filtering, sorting, search, and pagination without performing I/O.
  final BeakQuerySpec query;

  /// Eagerly includes typed to-one paths in each selected option record.
  BeakOptionQuery including(List<BeakToOneField> fields) {
    var loads = query.relationLoads;
    for (final field in fields) {
      if (field.model.table != model.table) {
        throw BeakConfigurationException(
          'Included field ${field.qualifiedKey} does not belong to ${model.table}.',
        );
      }
      loads = _mergeOptionLoads(loads, [field.relationLoad]);
    }
    return BeakOptionQuery(
      model: model,
      query: BeakQuerySpec(
        table: query.table,
        filter: query.filter,
        sorts: query.sorts,
        search: query.search,
        relationLoads: loads,
        pagination: query.pagination,
        withTrashed: query.withTrashed,
      ),
    );
  }
}

List<BeakRelationLoad> _mergeOptionLoads(
  List<BeakRelationLoad> existing,
  List<BeakRelationLoad> added,
) {
  final merged = {for (final load in existing) load.relationKey: load};
  for (final load in added) {
    final previous = merged[load.relationKey];
    merged[load.relationKey] = previous == null
        ? load
        : BeakRelationLoad(
            previous.relationKey,
            filter: previous.filter,
            nested: _mergeOptionLoads(previous.nested, load.nested),
          );
  }
  return merged.values.toList();
}
