/// Log produced by pretend-mode migration runs.
library;

/// A single entry in a pretend-mode log.
final class MigrationPretendEntry {
  /// Creates a [MigrationPretendEntry].
  const MigrationPretendEntry({required this.migration, required this.sql});

  /// Migration that emitted this entry.
  final String migration;

  /// Rendered DDL that would execute.
  final String sql;

  /// Serializes the entry to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'migration': migration,
    'sql': sql,
  };
}

/// Collection of pretend-mode log entries returned by the
/// migration runner.
final class MigrationPretendLog {
  /// Creates a [MigrationPretendLog].
  const MigrationPretendLog(this.entries);

  /// Empty log.
  const MigrationPretendLog.empty() : entries = const <MigrationPretendEntry>[];

  /// Entries in execution order.
  final List<MigrationPretendEntry> entries;

  /// Whether any entries were captured.
  bool get isEmpty => entries.isEmpty;
}
