/// Lifecycle hook surface for Model.
library;

import '../event/lifecycle_event.dart';

/// Lifecycle hooks and dispatcher entry points for Model.
///
/// Mixed into Model so concrete subclasses inherit no-op
/// defaults for every hook. Override only the ones you care
/// about; returning `false` from a `before*` hook cancels the
/// surrounding operation.
mixin ModelHooks {
  /// Fires before validation; return `false` to cancel.
  Future<bool> beforeValidate() async => true;

  /// Fires after validation succeeds.
  Future<void> afterValidate() async {}

  /// Fires before any save; return `false` to cancel.
  Future<bool> beforeSave() async => true;

  /// Fires before an INSERT; return `false` to cancel.
  Future<bool> beforeCreate() async => true;

  /// Fires after an INSERT.
  Future<void> afterCreate() async {}

  /// Fires before an UPDATE; return `false` to cancel.
  Future<bool> beforeUpdate() async => true;

  /// Fires after an UPDATE.
  Future<void> afterUpdate() async {}

  /// Fires after any save.
  Future<void> afterSave() async {}

  /// Fires before a DELETE; return `false` to cancel.
  Future<bool> beforeDelete() async => true;

  /// Fires after a DELETE.
  Future<void> afterDelete() async {}

  /// Fires after a model is hydrated from a row.
  Future<void> afterHydrate() async {}

  /// Fires before a soft-deleted model is restored; return `false`
  /// to cancel.
  Future<bool> beforeRestore() async => true;

  /// Fires after a soft-deleted model is restored.
  Future<void> afterRestore() async {}

  /// Invoke this model's hook for a cancelable [event].
  ///
  /// Returns the value the hook returned, or `true` for events
  /// without a corresponding hook on Model.
  Future<bool> invokeHook(LifecycleEvent event) async => switch (event) {
    LifecycleEvent.beforeValidate => beforeValidate(),
    LifecycleEvent.beforeSave => beforeSave(),
    LifecycleEvent.beforeCreate => beforeCreate(),
    LifecycleEvent.beforeUpdate => beforeUpdate(),
    LifecycleEvent.beforeDelete => beforeDelete(),
    LifecycleEvent.beforeRestore => beforeRestore(),
    _ => Future<bool>.value(true),
  };

  /// Invoke this model's hook for a non-cancelable [event].
  Future<void> invokeAfterHook(LifecycleEvent event) async {
    switch (event) {
      case LifecycleEvent.afterValidate:
        await afterValidate();
      case LifecycleEvent.afterCreate:
        await afterCreate();
      case LifecycleEvent.afterUpdate:
        await afterUpdate();
      case LifecycleEvent.afterSave:
        await afterSave();
      case LifecycleEvent.afterDelete:
        await afterDelete();
      case LifecycleEvent.afterHydrate:
        await afterHydrate();
      case LifecycleEvent.afterRestore:
        await afterRestore();
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
