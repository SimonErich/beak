/// Soft-delete infrastructure for models.
///
/// The query-side machinery — `SoftDeleteScope`,
/// `QueryBuilder.withTrashed`, `QueryBuilder.onlyTrashed`
/// — is implemented in `lib/src/scope/soft_delete_scope.dart`
/// and `lib/src/query/query_builder.dart`.
///
/// This file owns the column constant and the
/// [SoftDeletes] mixin, which provides the
/// `delete` / `restore` / `forceDelete` instance API.
library;

import '../adapter/database_adapter.dart';
import '../event/lifecycle_event.dart';
import '../model/model.dart';
import '../query/delete_descriptor.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/update_descriptor.dart';
import '../registry/worm.dart';
import '../transaction/transaction_context.dart';
import 'active_record.dart';

/// Default column name carrying the soft-delete
/// timestamp.
const String softDeleteColumn = 'deleted_at';

/// Mixin adding soft-delete semantics to a [Model].
///
/// Mixing this in adds:
///
/// - mutable [deletedAt] state hydrated from the row,
/// - `save()` — persists the model via `UPDATE`,
/// - `delete()` — soft delete (sets [deletedAt] and
///   calls `save()`; never calls `adapter.delete()`),
/// - `restore()` — clears [deletedAt] and persists,
/// - `forceDelete()` — bypasses hooks and issues
///   `adapter.delete()` directly.
///
/// Hosts must implement the [softDeleteAdapter] and
/// [softDeleteTable] hooks so the mixin can route
/// queries through the model's existing adapter
/// binding. The [softDeletePrimaryKey] defaults to
/// `'id'`; override to customize. Lifecycle hooks
/// (`onSaving`, `onDeleting`, etc.) land in EPIC-006 —
/// today `delete`/`restore`/`forceDelete` issue exactly
/// one adapter call each.
mixin SoftDeletes on Model {
  DateTime? _deletedAt;

  /// Adapter the mixin uses for `UPDATE` / `DELETE`.
  ///
  /// Hosts wire this to the model's bound adapter.
  DatabaseAdapter get softDeleteAdapter;

  /// Table the model lives in.
  String get softDeleteTable;

  /// Primary-key column on [softDeleteTable].
  String get softDeletePrimaryKey => 'id';

  /// Column carrying the soft-delete timestamp.
  String get softDeleteAtColumn => softDeleteColumn;

  /// Current soft-delete timestamp, or `null` when the
  /// row is live.
  DateTime? get deletedAt => _deletedAt;

  /// Used by hydrators to seed [deletedAt] from a row.
  set deletedAt(DateTime? value) {
    _deletedAt = value;
  }

  /// Whether this model is currently soft-deleted.
  bool get isTrashed => _deletedAt != null;

  /// Persists this model's current state via `UPDATE`.
  ///
  /// Overrides [Model.save] to bypass the Active Record
  /// hook pipeline — soft-delete persistence is a single
  /// targeted UPDATE that ignores lifecycle hooks
  /// (matching `forceDelete()`'s parallel design).
  /// Always returns `true` so soft-delete callers can
  /// treat the result as the canonical save outcome.
  @override
  Future<bool> save({TransactionContext? transaction}) async {
    await _routedAdapter(transaction).update(
      UpdateDescriptor(
        table: softDeleteTable,
        values: toRow(),
        where: Field<Object?>(softDeletePrimaryKey).eq(id),
      ),
    );
    return true;
  }

  /// Soft-deletes this model.
  ///
  /// Sets [deletedAt] to `DateTime.now()` and calls
  /// [save] — never issues `adapter.delete()`. Always
  /// returns `true`.
  @override
  Future<bool> delete({TransactionContext? transaction}) async {
    _deletedAt = DateTime.now();
    return save(transaction: transaction);
  }

  /// Resolve the adapter for a soft-delete write, preferring an active
  /// transaction's handle so soft deletes participate in the surrounding
  /// `Worm.transaction`.
  DatabaseAdapter _routedAdapter(TransactionContext? transaction) {
    final txn = transaction ?? Worm.currentTransaction;
    if (txn != null && txn.connectionName == connectionName) {
      return txn.adapter;
    }
    return softDeleteAdapter;
  }

  /// Restores a soft-deleted model.
  ///
  /// Fires [beforeRestore] (which may cancel), clears [deletedAt],
  /// persists via [save], then fires [afterRestore]. After `restore()`
  /// the model reappears in queries gated by `SoftDeleteScope`.
  /// Returns `true` on success, `false` when [beforeRestore] cancels.
  Future<bool> restore({TransactionContext? transaction}) async {
    final dispatcher = ActiveRecord.dispatcherFor(this);
    if (!await dispatcher.dispatchBefore(LifecycleEvent.beforeRestore, this)) {
      return false;
    }
    _deletedAt = null;
    await save(transaction: transaction);
    await dispatcher.dispatchAfter(LifecycleEvent.afterRestore, this);
    return true;
  }

  /// Hard-deletes this model, bypassing the soft-delete path.
  ///
  /// Issues a single real `DELETE`, so the row no longer appears even
  /// in `withTrashed()` results. Routes through an active transaction
  /// when one is in scope. Returns `true` on completion.
  @override
  Future<bool> forceDelete({TransactionContext? transaction}) async {
    await _routedAdapter(transaction).delete(
      DeleteDescriptor(
        table: softDeleteTable,
        where: Field<Object?>(softDeletePrimaryKey).eq(id),
      ),
    );
    return true;
  }
}
