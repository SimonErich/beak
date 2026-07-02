/// The referential action Beak applies to dependent rows when a record is
/// deleted.
///
/// Mirrors worm's `OnDelete` enum 1:1 (same names, same order) so
/// `beak_backend` can translate values mechanically — `beak_core` itself
/// never imports worm, keeping the metadata ORM-agnostic for future data
/// sources.
enum BeakOnDelete {
  /// Delete dependent rows automatically via the database engine.
  /// Maps to worm `OnDelete.cascade`.
  cascade,

  /// Delete dependent rows from the ORM side, firing every model lifecycle
  /// hook on each child (the database itself takes no action).
  /// Maps to worm `OnDelete.ormCascade`.
  ormCascade,

  /// Prevent deletion while dependent rows exist.
  /// Maps to worm `OnDelete.restrict`.
  restrict,

  /// Set the foreign key column of dependent rows to `NULL`.
  /// Maps to worm `OnDelete.setNull`.
  setNull,

  /// Set the foreign key column of dependent rows to its default.
  /// Maps to worm `OnDelete.setDefault`.
  setDefault,

  /// Take no action (database default behavior).
  /// Maps to worm `OnDelete.noAction`.
  noAction,
}
