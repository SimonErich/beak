/// Run record for an executed seeder.
library;

/// A row stored in the seeder tracking repository.
///
/// Mirrors the `MigrationRecord` shape so adapter-side
/// persistence remains uniform across the runner stack.
final class SeederRecord {
  /// Creates a [SeederRecord].
  const SeederRecord({required this.name, required this.executedAt});

  /// Default tracking table for [SeederRecord] persistence.
  ///
  /// Adapters create / read this table via `SchemaDescriptor`
  /// and `InsertDescriptor` descriptors keyed on this name.
  static const String tableName = 'worm_seeders';

  /// Column name for [name] in the tracking table.
  static const String columnName = 'name';

  /// Column name for [executedAt] in the tracking table.
  static const String columnExecutedAt = 'executed_at';

  /// The seeder's [name].
  final String name;

  /// Timestamp of execution (UTC).
  final DateTime executedAt;

  /// Serializes the record to a plain map for insertion.
  Map<String, Object?> toMap() => <String, Object?>{
    columnName: name,
    columnExecutedAt: executedAt.toIso8601String(),
  };

  /// Hydrates a [SeederRecord] from a raw tracking row.
  ///
  /// Uses pattern matching — no `as` casts. Throws
  /// [FormatException] when the row shape is invalid.
  static SeederRecord fromRow(Map<String, Object?> row) {
    final name = switch (row[columnName]) {
      final String value => value,
      _ => throw const FormatException(
        'SeederRecord row is missing String column "name"',
      ),
    };
    final executedAt = switch (row[columnExecutedAt]) {
      final String value => DateTime.parse(value),
      final DateTime value => value,
      _ => throw const FormatException(
        'SeederRecord row is missing column "executed_at"',
      ),
    };
    return SeederRecord(name: name, executedAt: executedAt);
  }
}
