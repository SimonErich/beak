import 'package:meta/meta.dart';

import '../columns/beak_column.dart';
import '../common/beak_exception.dart';
import '../context/beak_context.dart';
import '../query/beak_record.dart';
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
