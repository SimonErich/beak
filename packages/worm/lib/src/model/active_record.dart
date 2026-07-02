/// Active Record orchestration: `save` / `delete` / `refresh`.
library;

import '../adapter/database_adapter.dart';
import '../event/event_dispatcher.dart';
import '../event/lifecycle_event.dart';
import '../event/lifecycle_handler.dart';
import '../exception/configuration_exception.dart';
import '../exception/model_not_found_exception.dart';
import '../query/delete_descriptor.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/insert_descriptor.dart';
import '../query/query_descriptor.dart';
import '../query/update_descriptor.dart';
import '../registry/worm.dart';
import '../transaction/transaction_context.dart';
import '../validation/validation_rule.dart';
import '../validation/validator.dart';
import 'model.dart';
import 'model_lookup.dart';

/// Stateless orchestrator for [Model] write operations.
///
/// Wires the model's lifecycle hooks and every registered
/// [LifecycleHandler] around the matching adapter call. A `false`
/// from any `before*` hook cancels the operation and short-circuits
/// the chain.
abstract final class ActiveRecord {
  /// Persist [model]; INSERT when new, UPDATE when [Model.exists].
  ///
  /// Returns `true` on success; `false` when any `before*` hook
  /// cancels.
  static Future<bool> save(
    Model model, {
    TransactionContext? transaction,
  }) async {
    final txn = transaction ?? Worm.currentTransaction;
    final dispatcher = dispatcherFor(model);
    if (!await dispatcher.dispatchBefore(
      LifecycleEvent.beforeValidate,
      model,
    )) {
      return false;
    }
    await _runValidation(model);
    await dispatcher.dispatchAfter(LifecycleEvent.afterValidate, model);
    if (!await dispatcher.dispatchBefore(LifecycleEvent.beforeSave, model)) {
      return false;
    }
    final adapter = _resolveAdapter(model, txn);
    final result = model.exists
        ? await _runUpdate(model, dispatcher, adapter)
        : await _runInsert(model, dispatcher, adapter);
    if (!result) return false;
    await dispatcher.dispatchAfter(LifecycleEvent.afterSave, model);
    _settleAfterCommit(model, txn);
    return true;
  }

  /// Delete [model]. Returns `false` if [Model.beforeDelete]
  /// cancels.
  ///
  /// When the model declares any [Model.ormCascadeSpecs], the
  /// dependent rows for each spec are loaded, deleted one at a time
  /// (firing every child's lifecycle hooks), and the parent is
  /// deleted only after every child cascade succeeds. Cancellation
  /// by any child's `beforeDelete` aborts the cascade.
  static Future<bool> delete(
    Model model, {
    TransactionContext? transaction,
  }) async {
    final txn = transaction ?? Worm.currentTransaction;
    final dispatcher = dispatcherFor(model);
    if (!await dispatcher.dispatchBefore(LifecycleEvent.beforeDelete, model)) {
      return false;
    }
    final adapter = _resolveAdapter(model, txn);
    final table = _tableFor(model);
    if (!await _cascadeChildren(model, adapter, txn)) return false;
    await adapter.delete(
      DeleteDescriptor(
        table: table,
        where: Field<Object?>(model.primaryKeyColumn).eq(model.id),
      ),
    );
    model.state.exists = false;
    await dispatcher.dispatchAfter(LifecycleEvent.afterDelete, model);
    _settleAfterCommit(model, txn);
    return true;
  }

  /// Walk every [Model.ormCascadeSpecs] entry, deleting each child
  /// row through the ORM so all lifecycle hooks fire. Cascade deletes
  /// share the parent's [txn] so they commit or roll back together.
  ///
  /// Returns `false` (and stops cascading) when any child's
  /// `beforeDelete` cancels.
  static Future<bool> _cascadeChildren(
    Model model,
    DatabaseAdapter adapter,
    TransactionContext? txn,
  ) async {
    final specs = model.ormCascadeSpecs;
    if (specs.isEmpty) return true;
    for (final spec in specs) {
      final field = Field<Object?>(spec.foreignKey);
      final rows = await adapter.select(
        QueryDescriptor(table: spec.childTable, where: field.eq(model.id)),
      );
      for (final row in rows) {
        final child = spec.hydrate(row)..markPersisted();
        final ok = await delete(child, transaction: txn);
        if (!ok) return false;
      }
    }
    return true;
  }

  /// Re-read [model] from the database and seed its attributes.
  static Future<void> refresh(Model model) async {
    final adapter = _resolveAdapter(model, Worm.currentTransaction);
    final table = _tableFor(model);
    final row = await adapter.selectOne(
      QueryDescriptor(
        table: table,
        where: Field<Object?>(model.primaryKeyColumn).eq(model.id),
        limit: 1,
      ),
    );
    if (row == null) {
      throw ModelNotFoundException(
        model: '${model.runtimeType}',
        id: model.id,
        message: 'Refresh failed: no row for "${model.id}" in "$table"',
      );
    }
    final decoded = model.castManager.decodeAll(row);
    for (final entry in decoded.entries) {
      model.hydrateAttribute(entry.key, entry.value);
    }
    model.markPersisted();
    final dispatcher = dispatcherFor(model);
    await dispatcher.dispatchAfter(LifecycleEvent.afterHydrate, model);
  }

  static Future<bool> _runInsert(
    Model model,
    EventDispatcher dispatcher,
    DatabaseAdapter adapter,
  ) async {
    if (!await dispatcher.dispatchBefore(LifecycleEvent.beforeCreate, model)) {
      return false;
    }
    final table = _tableFor(model);
    final values = <String, Object?>{...model.toRow()};
    if (model.usesTimestamps && !model.state.withoutTimestamps) {
      final now = DateTime.now().toUtc();
      values
        ..[model.createdAtColumn] = now
        ..[model.updatedAtColumn] = now;
      model
        ..hydrateAttribute(model.createdAtColumn, now)
        ..hydrateAttribute(model.updatedAtColumn, now);
    }
    final encoded = model.castManager.encodeAll(values);
    await adapter.insert(InsertDescriptor(table: table, values: encoded));
    model.markPersisted();
    await dispatcher.dispatchAfter(LifecycleEvent.afterCreate, model);
    return true;
  }

  static Future<bool> _runUpdate(
    Model model,
    EventDispatcher dispatcher,
    DatabaseAdapter adapter,
  ) async {
    if (!await dispatcher.dispatchBefore(LifecycleEvent.beforeUpdate, model)) {
      return false;
    }
    final table = _tableFor(model);
    final values = _updatePayload(model);
    if (model.usesTimestamps && !model.state.withoutTimestamps) {
      final now = DateTime.now().toUtc();
      values[model.updatedAtColumn] = now;
      model.hydrateAttribute(model.updatedAtColumn, now);
    }
    if (values.isNotEmpty) {
      final encoded = model.castManager.encodeAll(values);
      await adapter.update(
        UpdateDescriptor(
          table: table,
          values: encoded,
          where: Field<Object?>(model.primaryKeyColumn).eq(model.id),
        ),
      );
    }
    model.state.syncOriginal();
    await dispatcher.dispatchAfter(LifecycleEvent.afterUpdate, model);
    return true;
  }

  /// Build the UPDATE payload.
  ///
  /// When the user wired the attribute store (state.attributes non
  /// empty), send just the dirty subset to satisfy the spec
  /// "only modified columns emitted" performance target. Otherwise
  /// fall back to [Model.toRow] for backwards compatibility with
  /// models that own their own serialization.
  static Map<String, Object?> _updatePayload(Model model) {
    if (model.state.attributes.isNotEmpty && model.state.dirty.isNotEmpty) {
      return <String, Object?>{
        for (final key in model.state.dirty) key: model.state.attributes[key],
      };
    }
    final row = <String, Object?>{...model.toRow()}
      ..remove(model.primaryKeyColumn);
    return row;
  }

  /// Run the model's declared validation rules, throwing
  /// `ValidationException` (which cancels the surrounding save) on any
  /// failure.
  ///
  /// New rows validate against [Model.rules]; existing rows validate
  /// against [Model.updateRules] but only for fields that are dirty,
  /// so an unchanged legacy column never blocks an unrelated edit.
  /// Models without rules short-circuit before any [Validator] is
  /// built, so they pay no validation cost.
  static Future<void> _runValidation(Model model) async {
    final ruleMap = model.exists ? model.updateRules : model.rules;
    if (ruleMap.isEmpty) return;
    final rules = <String, List<ValidationRule>>{};
    final values = <String, Object?>{};
    for (final entry in ruleMap.entries) {
      final column = entry.key.name;
      if (model.exists && !model.isDirty(column)) continue;
      rules[column] = entry.value;
      values[column] = model.getAttribute(column);
    }
    if (rules.isEmpty) return;
    await Validator(rules).validateOrThrow(values);
  }

  /// Build the [EventDispatcher] for [model] from its registered
  /// observers. Public so the `SoftDeletes` mixin can fire its own
  /// restore events through the same handler chain.
  static EventDispatcher dispatcherFor(Model model) {
    if (!Worm.isInitialized) return const EventDispatcher(<LifecycleHandler>[]);
    final handlers = <LifecycleHandler>[
      for (final observer in Worm.observersFor(model.runtimeType))
        if (observer case final LifecycleHandler handler) handler,
    ];
    return EventDispatcher(handlers);
  }

  static DatabaseAdapter _adapterFor(Model model) {
    if (!Worm.isInitialized) {
      throw const ConfigurationException(
        key: 'initialization',
        message: 'Worm.initialize() must be called before model persistence',
      );
    }
    return Worm.adapter(model.connectionName);
  }

  /// Resolve the adapter for a write, preferring the transactional
  /// handle when [txn] targets the model's connection so every write
  /// in one operation shares a single transaction.
  static DatabaseAdapter _resolveAdapter(Model model, TransactionContext? txn) {
    if (txn != null && txn.connectionName == model.connectionName) {
      return txn.adapter;
    }
    return _adapterFor(model);
  }

  static String _tableFor(Model model) => ModelLookup.tableNameOf(model);

  /// Settle a model's queued `afterCommit` callbacks: defer them onto
  /// the active [txn] (fired when the transaction commits, discarded on
  /// rollback), or fire immediately when there is no transaction.
  static void _settleAfterCommit(Model model, TransactionContext? txn) {
    final callbacks = <void Function()>[...model.state.afterCommitCallbacks];
    model.state.afterCommitCallbacks.clear();
    if (txn != null) {
      for (final callback in callbacks) {
        txn.enqueueAfterCommit(callback);
      }
    } else {
      for (final callback in callbacks) {
        callback();
      }
    }
  }
}
