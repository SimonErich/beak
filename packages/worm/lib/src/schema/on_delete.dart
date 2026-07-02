/// Referential actions for foreign key deletes.
library;

/// Action taken when a referenced row is deleted.
enum OnDelete {
  /// Delete dependent rows automatically via the database engine.
  cascade,

  /// Delete dependent rows from the ORM side, firing every model
  /// lifecycle hook (`beforeDelete` / `afterDelete`) on each child.
  ///
  /// Distinct from [cascade]: the database is unaware of the cascade
  /// (foreign key is `noAction`), and the ORM walks every dependent
  /// row before issuing the parent delete so observers, soft-delete
  /// scopes, and `@CastAs` decoders all run.
  ormCascade,

  /// Prevent deletion if dependents exist.
  restrict,

  /// Set the foreign key column to `NULL`.
  setNull,

  /// Set the foreign key column to its default.
  setDefault,

  /// Take no action (database default).
  noAction,
}
