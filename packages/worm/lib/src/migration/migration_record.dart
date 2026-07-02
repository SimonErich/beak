/// Persistent record of an applied migration.
library;

/// One row in the `worm_migrations` tracking table.
///
/// Records the migration [name], the [batch] in which it was applied
/// (used by rollback), and the wall-clock instant of application.
final class MigrationRecord {
  /// Creates a [MigrationRecord].
  const MigrationRecord({
    required this.name,
    required this.batch,
    required this.appliedAt,
  });

  /// File-name identifier of the migration.
  final String name;

  /// Batch number this migration was applied in. Migrations applied
  /// together share a batch (used by rollback).
  final int batch;

  /// Instant the migration was applied.
  final DateTime appliedAt;

  /// Serializes the record to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'batch': batch,
    'applied_at': appliedAt.toIso8601String(),
  };
}
