/// Exception for irreversible migrations.
library;

import 'worm_exception.dart';

/// Thrown when a migration's `down` is invoked but
/// the migration cannot be rolled back.
///
/// Extends [WormException] directly: migration
/// orchestration is independent of the database
/// adapter that backs storage, so callers should
/// catch this exception by name rather than via
/// any adapter umbrella.
class IrreversibleMigrationException extends WormException {
  /// Creates an [IrreversibleMigrationException].
  const IrreversibleMigrationException({
    required this.migration,
    required String message,
    this.reason,
  }) : super(message);

  /// Name of the migration that cannot be reversed.
  final String migration;

  /// Optional human-readable reason explaining why
  /// the migration cannot be reversed.
  final String? reason;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'migration': migration,
    'reason': reason,
  };

  @override
  String toString() {
    final why = reason;
    if (why == null) {
      return 'IrreversibleMigrationException: $message '
          '(migration: $migration)';
    }
    return 'IrreversibleMigrationException: $message '
        '(migration: $migration, reason: $why)';
  }
}
