/// The live transaction handle handed to `Worm.transaction` callbacks.
library;

import 'package:meta/meta.dart';

import '../adapter/database_adapter.dart';
import '../exception/unsupported_operation_exception.dart';

/// A live database transaction.
///
/// Handed to the callback of `Worm.transaction`, accepted by
/// `Model.save(transaction:)` / `Model.delete(transaction:)`, and
/// reachable inside the callback via `Worm.currentTransaction`. Writes
/// routed through [adapter] participate in the transaction and roll
/// back together when the callback throws.
///
/// Each context owns its own ordered `afterCommit` queue: callbacks
/// registered by saves/deletes inside the transaction are deferred and
/// fired only after the outermost transaction commits — or discarded if
/// it rolls back. This is what makes `model.afterCommit(...)` honour the
/// "fires only after commit" contract.
final class TransactionContext {
  /// Creates a [TransactionContext] over a transactional [adapter].
  ///
  /// Constructed by the runtime; user code receives one, it does not
  /// build one.
  @internal
  TransactionContext({required this.adapter, required this.connectionName});

  /// The transactional adapter handle for this transaction.
  final DatabaseAdapter adapter;

  /// The connection name this transaction was opened on.
  final String connectionName;

  final List<void Function()> _afterCommit = <void Function()>[];

  /// Queue [callback] to run after the outermost transaction commits.
  @internal
  void enqueueAfterCommit(void Function() callback) {
    _afterCommit.add(callback);
  }

  /// Fire and clear every queued afterCommit callback, in order.
  @internal
  void drainAfterCommit() {
    final callbacks = <void Function()>[..._afterCommit];
    _afterCommit.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  /// Discard queued afterCommit callbacks without firing them.
  @internal
  void discardAfterCommit() {
    _afterCommit.clear();
  }

  /// Run [body] inside a savepoint.
  ///
  /// On success the savepoint is released and its work stays part of
  /// the enclosing transaction. When [body] throws, the savepoint rolls
  /// back — undoing only its own work, leaving the outer transaction
  /// intact — and the exception propagates. Any `afterCommit` callbacks
  /// registered while the savepoint was open are discarded on rollback.
  ///
  /// Throws [UnsupportedOperationException] when the backing adapter
  /// does not support savepoints (`capabilities.supportsSavepoints`).
  Future<T> savepoint<T>(Future<T> Function() body) async {
    if (!adapter.capabilities.supportsSavepoints) {
      throw UnsupportedOperationException(
        operation: 'savepoint',
        adapter: adapter.runtimeType.toString(),
        message:
            '${adapter.runtimeType} does not support savepoints '
            '(capabilities.supportsSavepoints is false)',
      );
    }
    final mark = _afterCommit.length;
    try {
      return await adapter.transaction<T>((_) => body());
    } on Object {
      if (_afterCommit.length > mark) {
        _afterCommit.removeRange(mark, _afterCommit.length);
      }
      rethrow;
    }
  }
}
