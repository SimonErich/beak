import '../behavior/beak_model_behavior.dart';
import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../columns/beak_json.dart';
import '../common/beak_exception.dart';
import '../context/beak_context.dart';
import '../data/beak_data_source.dart';
import '../query/beak_aggregate_spec.dart';
import '../query/beak_filter.dart';
import '../query/beak_record.dart';
import '../query/beak_pagination.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_relation_load.dart';
import '../query/beak_sort.dart';
import '../query/beak_value.dart';
import '../query/beak_table_ref.dart';
import '../relations/beak_relationship.dart';
import 'beak_permissions.dart';
import '../validation/beak_record_rule.dart';

/// ORM-agnostic metadata describing one admin resource: its table, columns,
/// relationships, delete semantics, and display column.
///
/// A model describes metadata and may bind a [dataSource]. The panel uses that
/// binding automatically; models without one use the panel's default source.
/// Persistence stays behind [BeakDataSource], so ORM-specific operations never
/// leak into forms, tables or application screens.
///
/// Subclass it once per resource, wiring up its columns, relationships, and
/// delete semantics:
///
/// ```dart
/// final class ProductModel extends BeakModel {
///   const ProductModel();
///
///   @override
///   String get table => 'products';
///
///   @override
///   String get displayColumnKey => 'name';
///
///   @override
///   List<BeakColumn> get columns => ProductColumns.values;
///
///   @override
///   List<BeakRelationship> get relationships => const [
///     ProductRelations.category,
///     ProductRelations.tags,
///   ];
///
///   @override
///   bool get softDeletes => true;
/// }
/// ```
///
/// Register the instance in a [BeakModelRegistry] so the backend and frontend
/// can resolve it by [table].
@immutable
abstract base class BeakModel {
  /// Enables `const` construction by subclasses.
  const BeakModel();

  /// Physical table/collection name backing this model.
  String get table;

  /// Key of the column that represents a record in pickers and links.
  String get displayColumnKey;

  /// The columns of this model, in display order.
  List<BeakColumn> get columns;

  /// Shared typed scalar, cross-field, collection and asynchronous constraints.
  List<BeakRecordRule> get validationRules => const [];

  /// Shared value lifecycles, workflow guards and named commands.
  BeakModelBehavior get behavior => const BeakModelBehavior();

  /// Live presentation policy shared by every resource using this model.
  BeakPermissions get permissions => const BeakPermissions.allowAll();

  /// Operations actually supported by this model's transport.
  ///
  /// Defaults to ordinary CRUD for HTTP/Worm models. Adapters narrow this set
  /// when an endpoint is absent; a custom screen may supply a missing workflow.
  Set<BeakOperation> get capabilities => const {
    BeakOperation.read,
    BeakOperation.create,
    BeakOperation.update,
    BeakOperation.delete,
  };

  /// Optional model-owned transport, registered automatically by the panel.
  ///
  /// Return a stable instance. A null source uses the panel's HTTP or explicitly
  /// supplied source, preserving the standalone handwritten-model workflow.
  BeakDataSource? get dataSource => null;

  /// Create command metadata when the write shape differs from the read model.
  BeakModel? get createModel => null;

  /// Update command metadata; an edit-capable source supplies its prefill data.
  BeakModel? get editModel => null;

  /// The relationships of this model. Defaults to none.
  List<BeakRelationship> get relationships => const [];

  /// Models referenced by this model, registered without navigation entries.
  ///
  /// Generated models supply these declarations so a panel only needs its
  /// visible resources. Cycles are resolved by the panel registry.
  List<BeakModel> get relatedModels => const [];

  /// Whether deletes are soft (a deleted-at marker the backend filters on)
  /// instead of physical row removal. Defaults to `false`.
  bool get softDeletes => false;

  /// The pool of enum values this model's forms take a field slot from, or
  /// `null` for Beak's default pool.
  ///
  /// Auto forms key their fields by a Dart enum, for compile-time safety;
  /// Beak's columns are runtime values. A form therefore claims one enum
  /// value per field it registers, and the pool has to be at least as large
  /// as the form. The default pool holds 32, which is more fields than a form
  /// a person can read — but not more than a wide table has columns.
  ///
  /// A generated model supplies a pool sized to itself, so the question never
  /// arises. Override this on a hand-written model that needs a bigger one:
  ///
  /// ```dart
  /// enum _WideSlots { s0, s1, /* ...as many as the form needs... */ }
  ///
  /// @override
  /// List<Enum> get formSlots => _WideSlots.values;
  /// ```
  ///
  /// The values are never shown and never stored; only their count and their
  /// distinctness matter.
  List<Enum>? get formSlots => null;

  /// The primary-key column: by default the first column with key `'id'`.
  ///
  /// Throws a [BeakConfigurationException] when no such column exists and
  /// the model does not override this getter with its actual key column.
  BeakColumn get primaryKey {
    final column = columnByKey('id');
    if (column == null) {
      throw BeakConfigurationException(
        'Model "$table" has no column with key "id"; add one or override '
        'primaryKey.',
      );
    }
    return column;
  }

  /// A typed reference to this model's [table].
  ///
  /// Hand this to any API that needs to name the table, so the name is
  /// derived from the model instead of retyped as a string.
  BeakTableRef get ref => BeakTableRef.raw(table);

  /// A query over this model's table.
  ///
  /// The typed entry point into [BeakQuerySpec]: chain the copy-builders from
  /// here and no table string is ever written.
  ///
  /// ```dart
  /// const ProductModel().query()
  ///     .orderBy(ProductColumns.price, descending: true)
  ///     .paginate(perPage: 10);
  /// ```
  ///
  /// Mirrors [BeakQuerySpec]'s own parameters, so anything expressible there
  /// is expressible here without naming the table.
  BeakQuerySpec query({
    BeakFilter? filter,
    List<BeakSort> sorts = const [],
    BeakSearch? search,
    List<BeakRelationLoad> relationLoads = const [],
    BeakPagination pagination = const BeakPagination(),
    bool withTrashed = false,
  }) => BeakQuerySpec(
    table: table,
    filter: filter,
    sorts: sorts,
    search: search,
    relationLoads: relationLoads,
    pagination: pagination,
    withTrashed: withTrashed,
  );

  /// Counts this model's rows, optionally narrowed by [filter].
  BeakAggregateSpec count({BeakFilter? filter, bool withTrashed = false}) =>
      BeakAggregateSpec.count(
        table: table,
        filter: filter,
        withTrashed: withTrashed,
      );

  /// Sums [column] over this model's rows.
  ///
  /// [column] should be numeric ([BeakIntColumn] or [BeakDecimalColumn]);
  /// the data source rejects anything else. Results use physical storage units;
  /// exact decimal fields offer a typed `field.sum(source)` helper.
  BeakAggregateSpec sum(
    BeakColumn column, {
    BeakFilter? filter,
    bool withTrashed = false,
  }) => BeakAggregateSpec.sum(
    table: table,
    column: column,
    filter: filter,
    withTrashed: withTrashed,
  );

  /// Averages [column] over this model's rows, returning physical storage units.
  /// Fixed-scale money may produce fractional units; choose rounding explicitly.
  BeakAggregateSpec avg(
    BeakColumn column, {
    BeakFilter? filter,
    bool withTrashed = false,
  }) => BeakAggregateSpec.avg(
    table: table,
    column: column,
    filter: filter,
    withTrashed: withTrashed,
  );

  /// The primary-key value of [record], or `null` when the record does not
  /// carry it — the single way Beak extracts a record's id.
  Object? primaryKeyOf(BeakRecord record) => record[primaryKey.key]?.raw;

  /// The columns visible in [context], in declaration order.
  List<BeakColumn> columnsFor(BeakContext context) => [
    for (final column in columns)
      if (column.visibleOn.contains(context)) column,
  ];

  /// The first column stored under [key], or `null` when none matches.
  BeakColumn? columnByKey(String key) {
    for (final column in columns) {
      if (column.key == key) {
        return column;
      }
    }
    return null;
  }

  /// The first relationship named [key], or `null` when none matches.
  BeakRelationship? relationshipByKey(String key) {
    for (final relationship in relationships) {
      if (relationship.key == key) {
        return relationship;
      }
    }
    return null;
  }
}

/// [raw] as the [BeakValue] [column] describes.
///
/// A database says what it can: SQLite has no boolean, date or decimal type,
/// so a row comes back with `1` where the model declares a flag and a string
/// where it declares an instant. Typing values by their Dart runtime type
/// alone therefore produces a record whose shape depends on the driver — the
/// panel renders `1` instead of a badge, and a conditional update cannot find
/// the timestamp it was asked to compare.
///
/// This is the one place that decides, so every data source agrees. A value
/// the column cannot read keeps its literal form rather than being dropped.
BeakValue beakValueForColumn(BeakColumn? column, Object? raw) {
  if (column is BeakJsonColumn &&
      !column.semantic.hasCodec &&
      raw is BeakJson) {
    return BeakStringValue(raw.encode());
  }
  if (column != null && column.semantic.hasCodec) {
    // Typed callers and drivers meet at the same canonical primitive shape.
    // Preserve malformed driver data so boundary validation can report it.
    try {
      return column.semantic.encode(raw);
    } on FormatException {
      return BeakValue.of(raw);
    }
  }
  final BeakValue value = BeakValue.of(raw is Enum ? raw.name : raw);
  return switch (column) {
        BeakBoolColumn() => switch (column.readValue(value)) {
          final bool parsed => BeakBoolValue(parsed),
          null => null,
        },
        BeakDateTimeColumn() => switch (column.readValue(value)) {
          final DateTime parsed => BeakDateTimeValue(parsed),
          null => null,
        },
        BeakDecimalColumn() => switch (column.readValue(value)) {
          final double parsed => BeakDoubleValue(parsed),
          null => null,
        },
        BeakIntColumn() => switch (column.readValue(value)) {
          final int parsed => BeakIntValue(parsed),
          null => null,
        },
        _ => null,
      } ??
      value;
}
