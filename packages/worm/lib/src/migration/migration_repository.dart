/// Tracks applied migrations between runs.
library;

import 'migration_record.dart';

/// Contract for storing migration application history.
///
/// Implementations decide where to persist the data. The
/// default [InMemoryMigrationRepository] is suitable for
/// tests and lightweight setups; adapter packages may
/// provide DB-backed implementations.
abstract class MigrationRepository {
  /// Creates a [MigrationRepository].
  const MigrationRepository();

  /// Ensures the underlying tracking storage exists.
  Future<void> initialize();

  /// All records currently stored, ordered by batch.
  Future<List<MigrationRecord>> all();

  /// Records that a migration was applied.
  Future<void> record(MigrationRecord record);

  /// Removes a previously stored migration record.
  Future<void> forget(String name);

  /// The highest currently-recorded batch number.
  Future<int> latestBatch();
}

/// In-memory implementation suitable for tests and CI.
final class InMemoryMigrationRepository extends MigrationRepository {
  /// Creates an [InMemoryMigrationRepository].
  InMemoryMigrationRepository();

  final List<MigrationRecord> _records = <MigrationRecord>[];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<List<MigrationRecord>> all() async {
    _ensureInitialized();
    return List<MigrationRecord>.unmodifiable(_records);
  }

  @override
  Future<void> record(MigrationRecord record) async {
    _ensureInitialized();
    _records.add(record);
  }

  @override
  Future<void> forget(String name) async {
    _ensureInitialized();
    _records.removeWhere((r) => r.name == name);
  }

  @override
  Future<int> latestBatch() async {
    _ensureInitialized();
    if (_records.isEmpty) return 0;
    return _records.map((r) => r.batch).reduce((a, b) => a > b ? a : b);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'MigrationRepository.initialize() must be called first.',
      );
    }
  }
}
