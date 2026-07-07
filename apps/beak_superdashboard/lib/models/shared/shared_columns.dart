import 'package:beak_core/beak_core.dart';

/// Columns every model shares, declared once and reused from each model's
/// `columns` list — the DRY spine of the schema.
///
/// The three names ([id], [createdAt], [updatedAt]) are table-agnostic, so a
/// single `const` declaration serves every table instead of being re-typed
/// per model.
abstract final class SharedColumns {
  /// UUID primary key, shown only on the detail view.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'ID',
    visibleOn: {BeakContext.detail},
  );

  /// Row creation timestamp, stamped by the backend.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created',
    sortable: true,
    visibleOn: {BeakContext.detail},
  );

  /// Last-update timestamp, rendered relatively in tables.
  static const updatedAt = BeakDateTimeColumn(
    key: 'updated_at',
    label: 'Updated',
    format: BeakDateFormat.relative,
    sortable: true,
    visibleOn: {BeakContext.table, BeakContext.detail},
  );
}
