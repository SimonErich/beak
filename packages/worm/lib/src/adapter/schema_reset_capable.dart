/// Explicit schema-rebuild boundary for adapters with cyclic foreign keys.
library;

import 'database_adapter.dart';

/// Supports an atomic destructive rebuild with final integrity validation.
///
/// This capability is used by `MigrationRunner.fresh`, never ordinary CRUD or
/// transaction callbacks. Implementations may defer foreign-key checks while
/// tables are dropped and recreated, but must validate before committing and
/// restore the normal checking mode on success and failure.
abstract mixin class SchemaResetCapable {
  /// Runs [rebuild] against an isolated transactional schema adapter.
  Future<T> resetSchema<T>(Future<T> Function(DatabaseAdapter adapter) rebuild);
}
