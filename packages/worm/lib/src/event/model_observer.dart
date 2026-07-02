/// Lifecycle observer base class for models.
library;

import '../model/model.dart';
import '../registry/observer.dart';
import 'lifecycle_event.dart';
import 'lifecycle_handler.dart';

/// Observes lifecycle events for models of type [T].
///
/// Each hook has a no-op default so subclasses override only the
/// events they care about. `before*` hooks may return `false` to
/// cancel the operation; doing so prevents the database call and
/// any later hooks for the same operation.
///
/// Register observers via `Worm.initialize(observers: ...)`.
///
/// ```dart
/// class AuditObserver extends ModelObserver<User> {
///   const AuditObserver();
///
///   @override
///   Future<void> afterCreate(User model) async {
///     // record audit log
///   }
/// }
/// ```
abstract class ModelObserver<T extends Model> extends Observer<T>
    implements LifecycleHandler {
  /// Creates a [ModelObserver].
  const ModelObserver();

  /// Called before validation; return `false` to cancel.
  Future<bool> beforeValidate(T model) async => true;

  /// Called after validation succeeds.
  Future<void> afterValidate(T model) async {}

  /// Called before any save; return `false` to cancel.
  Future<bool> beforeSave(T model) async => true;

  /// Called before an INSERT; return `false` to cancel.
  Future<bool> beforeCreate(T model) async => true;

  /// Called after an INSERT.
  Future<void> afterCreate(T model) async {}

  /// Called before an UPDATE; return `false` to cancel.
  Future<bool> beforeUpdate(T model) async => true;

  /// Called after an UPDATE.
  Future<void> afterUpdate(T model) async {}

  /// Called after any save.
  Future<void> afterSave(T model) async {}

  /// Called before a DELETE; return `false` to cancel.
  Future<bool> beforeDelete(T model) async => true;

  /// Called after a DELETE.
  Future<void> afterDelete(T model) async {}

  /// Called after a model is hydrated from a row.
  Future<void> afterHydrate(T model) async {}

  /// Called before a soft-deleted model is restored; return `false`
  /// to cancel.
  Future<bool> beforeRestore(T model) async => true;

  /// Called after a soft-deleted model is restored.
  Future<void> afterRestore(T model) async {}

  @override
  Future<bool> dispatchBefore(LifecycleEvent event, Model model) async {
    if (model is! T) return true;
    return switch (event) {
      LifecycleEvent.beforeValidate => beforeValidate(model),
      LifecycleEvent.beforeSave => beforeSave(model),
      LifecycleEvent.beforeCreate => beforeCreate(model),
      LifecycleEvent.beforeUpdate => beforeUpdate(model),
      LifecycleEvent.beforeDelete => beforeDelete(model),
      LifecycleEvent.beforeRestore => beforeRestore(model),
      _ => Future<bool>.value(true),
    };
  }

  @override
  Future<void> dispatchAfter(LifecycleEvent event, Model model) async {
    if (model is! T) return;
    switch (event) {
      case LifecycleEvent.afterValidate:
        await afterValidate(model);
      case LifecycleEvent.afterCreate:
        await afterCreate(model);
      case LifecycleEvent.afterUpdate:
        await afterUpdate(model);
      case LifecycleEvent.afterSave:
        await afterSave(model);
      case LifecycleEvent.afterDelete:
        await afterDelete(model);
      case LifecycleEvent.afterHydrate:
        await afterHydrate(model);
      case LifecycleEvent.afterRestore:
        await afterRestore(model);
      case LifecycleEvent.beforeValidate:
      case LifecycleEvent.beforeSave:
      case LifecycleEvent.beforeCreate:
      case LifecycleEvent.beforeUpdate:
      case LifecycleEvent.beforeDelete:
      case LifecycleEvent.beforeRestore:
        break;
    }
  }
}
