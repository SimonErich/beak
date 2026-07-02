/// Status reporting for migrations.
library;

/// Whether a migration is pending or has been applied.
enum MigrationState {
  /// Registered but never run.
  pending,

  /// Already run; recorded in the tracking table.
  applied,
}

/// One row in the `worm migrate:status` report.
final class MigrationStatus {
  /// Creates a [MigrationStatus].
  const MigrationStatus({required this.name, required this.state, this.batch});

  /// Migration name (file identifier).
  final String name;

  /// Whether the migration is applied.
  final MigrationState state;

  /// Batch number when applied; `null` for pending.
  final int? batch;

  /// Serializes the status to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'state': state.name,
    if (batch != null) 'batch': batch,
  };

  @override
  String toString() {
    final marker = state == MigrationState.applied ? '[x]' : '[ ]';
    final batchPart = batch == null ? '' : ' (batch $batch)';
    return '$marker $name$batchPart';
  }
}
