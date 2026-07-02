/// Adapter-type identification used by the adapter
/// context gates `.sql()` and `.mongo()`.
library;

import '../adapter/database_adapter.dart';

/// Identifies the broad family of a [DatabaseAdapter].
///
/// The gates `.sql()` and `.mongo()` on `QueryBuilder`
/// consult `DatabaseAdapter.adapterType` to decide
/// whether the caller is using the correct backend.
enum AdapterType {
  /// Relational backends with SQL surface
  /// (`worm_postgres`, future MySQL, SQLite adapters).
  sql,

  /// Document/Mongo-style backends (`worm_mongodb`).
  mongodb,

  /// The bundled in-memory adapter — supports neither
  /// raw SQL nor Mongo pipelines.
  inMemory,

  /// Default for third-party adapters that do not opt
  /// into one of the bundled families.
  custom,
}

/// Friendly name for an adapter used in error messages.
String adapterName(DatabaseAdapter adapter) => adapter.runtimeType.toString();
