/// Exception for migration lock contention.
library;

import 'worm_exception.dart';

/// Thrown when a migration cannot acquire the
/// migration advisory lock because another process
/// is already running migrations.
///
/// Extends [WormException] directly: migration
/// orchestration is independent of the database
/// adapter that backs storage, so callers should
/// catch this exception by name rather than via
/// any adapter umbrella.
class MigrationLockException extends WormException {
  /// Creates a [MigrationLockException].
  const MigrationLockException({
    required this.migration,
    required String message,
    this.lockHolder,
  }) : super(message);

  /// Name of the migration that could not acquire
  /// the lock.
  final String migration;

  /// Identifier of the process holding the lock,
  /// when known.
  final String? lockHolder;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'migration': migration,
    'lockHolder': lockHolder,
  };

  @override
  String toString() {
    final holder = lockHolder;
    if (holder == null) {
      return 'MigrationLockException: $message '
          '(migration: $migration)';
    }
    return 'MigrationLockException: $message '
        '(migration: $migration, lockHolder: $holder)';
  }
}
