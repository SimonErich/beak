import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../common/beak_exception.dart';
import '../context/beak_context.dart';
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

/// ORM-agnostic metadata describing one admin resource: its table, columns,
/// relationships, delete semantics, and display column.
///
/// A `BeakModel` describes metadata only — it never runs queries. The
/// backend pairs it with a `BeakDataSource`, which is the seam that lets
/// worm today and other ORMs later both drive the same Beak panels.
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

  /// The relationships of this model. Defaults to none.
  List<BeakRelationship> get relationships => const [];

  /// Whether deletes are soft (a deleted-at marker the backend filters on)
  /// instead of physical row removal. Defaults to `false`.
  bool get softDeletes => false;

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
  /// the data source rejects anything else.
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

  /// Averages [column] over this model's rows.
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
  final BeakValue value = BeakValue.of(raw);
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
