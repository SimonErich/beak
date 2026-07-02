/// Exception for migration failures.
library;

import 'adapter_exception.dart';

/// Thrown when a database migration fails.
class MigrationException extends AdapterException {
  /// Creates a [MigrationException].
  const MigrationException({required this.migration, required String message})
    : super(message);

  /// The name of the migration that failed.
  final String migration;

  @override
  Map<String, Object?> get context => <String, Object?>{'migration': migration};

  @override
  String toString() => 'MigrationException: $message (migration: $migration)';
}
