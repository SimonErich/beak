/// Lifecycle events fired by Model during save / delete / hydrate.
library;

/// Enumerates every lifecycle event the model dispatcher can fire.
///
/// The order of firing is documented per operation:
///
/// **Insert** (when `save()` is called on a non-existing model):
/// 1. [beforeValidate]
/// 2. [afterValidate]
/// 3. [beforeSave]
/// 4. [beforeCreate]
/// 5. *database INSERT*
/// 6. [afterCreate]
/// 7. [afterSave]
///
/// **Update** (when `save()` is called on an existing model):
/// 1. [beforeValidate]
/// 2. [afterValidate]
/// 3. [beforeSave]
/// 4. [beforeUpdate]
/// 5. *database UPDATE*
/// 6. [afterUpdate]
/// 7. [afterSave]
///
/// **Delete**:
/// 1. [beforeDelete]
/// 2. *database DELETE*
/// 3. [afterDelete]
///
/// **Hydration** (after a row is loaded and assigned):
/// 1. [afterHydrate]
///
/// **Restore** (when a soft-deleted model is restored):
/// 1. [beforeRestore]
/// 2. *database UPDATE clearing `deleted_at`*
/// 3. [afterRestore]
enum LifecycleEvent {
  /// Fires before validation runs.
  beforeValidate,

  /// Fires after validation succeeds.
  afterValidate,

  /// Fires before any save (insert or update).
  beforeSave,

  /// Fires immediately before an INSERT.
  beforeCreate,

  /// Fires immediately after an INSERT.
  afterCreate,

  /// Fires immediately before an UPDATE.
  beforeUpdate,

  /// Fires immediately after an UPDATE.
  afterUpdate,

  /// Fires after any save (insert or update).
  afterSave,

  /// Fires immediately before a DELETE.
  beforeDelete,

  /// Fires immediately after a DELETE.
  afterDelete,

  /// Fires after a model is hydrated from a row.
  afterHydrate,

  /// Fires before a soft-deleted model is restored; return `false`
  /// to cancel.
  beforeRestore,

  /// Fires after a soft-deleted model is restored.
  afterRestore,
}

/// Whether [event] is a "before" hook whose return value can cancel.
bool isCancelable(LifecycleEvent event) => switch (event) {
  LifecycleEvent.beforeValidate ||
  LifecycleEvent.beforeSave ||
  LifecycleEvent.beforeCreate ||
  LifecycleEvent.beforeUpdate ||
  LifecycleEvent.beforeDelete ||
  LifecycleEvent.beforeRestore => true,
  _ => false,
};
