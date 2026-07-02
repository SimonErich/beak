/// ORM-side cascade specification consumed during `Model.delete`.
library;

import '../model/model.dart';

/// Declarative cascade entry used by `ActiveRecord.delete` when a
/// parent is deleted under `OnDelete.ormCascade`.
///
/// Unlike a foreign-key cascade that fires in the database engine,
/// an [OrmCascadeSpec] walks the dependent rows through the ORM so
/// every child model's `beforeDelete` / `afterDelete` hooks run.
///
/// Spec emitters (generated companion code, hand-written models)
/// build the list once and expose it through
/// `Model.ormCascadeSpecs`. The list is consulted before the parent
/// DELETE so cancellation by any child's `beforeDelete` aborts the
/// whole cascade — failures are loud, not silent.
final class OrmCascadeSpec {
  /// Creates an [OrmCascadeSpec].
  const OrmCascadeSpec({
    required this.childTable,
    required this.foreignKey,
    required this.hydrate,
  });

  /// Snake_case table holding the child rows.
  final String childTable;

  /// Foreign-key column on the child table referencing the parent.
  final String foreignKey;

  /// Hydrator producing a [Model] from a raw row.
  final Model Function(Map<String, Object?>) hydrate;
}
