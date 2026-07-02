/// Per-model registration metadata.
library;

import '../schema/primary_key_type.dart';

/// Metadata registered for a single model type.
///
/// A compact descriptor supplied to
/// `Worm.initialize` so the runtime can resolve
/// morph types, the target connection, and the
/// primary-key strategy without reflection.
final class ModelRegistration {
  /// Creates a [ModelRegistration].
  const ModelRegistration({
    required this.type,
    required this.tableName,
    this.primaryKeyColumn = 'id',
    this.primaryKeyType = PrimaryKeyType.uuid,
    this.connection = 'default',
    this.morphName,
  });

  /// The Dart type of the model class.
  final Type type;

  /// Snake_case plural table name.
  final String tableName;

  /// Column name for the primary key.
  final String primaryKeyColumn;

  /// Primary-key generation strategy.
  final PrimaryKeyType primaryKeyType;

  /// Named connection this model targets.
  final String connection;

  /// Stable morph name for polymorphic
  /// relationships. Defaults to [tableName].
  final String? morphName;

  /// The effective morph name used for
  /// polymorphic storage.
  String get effectiveMorphName => morphName ?? tableName;
}
