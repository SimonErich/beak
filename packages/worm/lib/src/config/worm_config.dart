/// Top-level configuration for the worm ORM.
library;

import '../schema/primary_key_type.dart';
import '../seeder/environment.dart';
import 'connection_config.dart';
import 'strictness_config.dart';

/// Top-level worm ORM configuration.
///
/// Passed to `Worm.initialize`. Carries named connection configs,
/// defaults for primary keys and timestamps, strictness flags, and
/// the runtime [Environment].
final class WormConfig {
  /// Creates a [WormConfig] with canonical defaults.
  ///
  /// `defaultConnection='default'`, `poolSize=10`,
  /// `primaryKeyType=PrimaryKeyType.uuid`, `timestamps=true`,
  /// `softDeletes=false`, `environment=Environment.development`.
  /// `connections` starts empty; adapters are supplied separately to
  /// `Worm.initialize`.
  const WormConfig({
    this.defaultConnection = 'default',
    this.connections = const <String, ConnectionConfig>{},
    this.poolSize = 10,
    this.primaryKeyType = PrimaryKeyType.uuid,
    this.timestamps = true,
    this.softDeletes = false,
    this.strictness = const StrictnessConfig(),
    this.environment = Environment.development,
  });

  /// Name of the implicit default connection.
  final String defaultConnection;

  /// Named connection configs.
  final Map<String, ConnectionConfig> connections;

  /// Default pool size applied to connections that do not declare
  /// their own. Individual [ConnectionConfig] entries in
  /// [connections] may override this value.
  final int poolSize;

  /// Default primary-key strategy for models.
  final PrimaryKeyType primaryKeyType;

  /// Whether `createdAt` / `updatedAt` are managed automatically.
  final bool timestamps;

  /// Whether soft deletes are enabled by default (opt-in per model).
  final bool softDeletes;

  /// Strictness flags.
  final StrictnessConfig strictness;

  /// Runtime environment. Overridden at runtime by `WORM_ENV` in
  /// `Worm.environment`.
  final Environment environment;

  /// Returns a copy of this config with selected fields overridden.
  WormConfig copyWith({
    String? defaultConnection,
    Map<String, ConnectionConfig>? connections,
    int? poolSize,
    PrimaryKeyType? primaryKeyType,
    bool? timestamps,
    bool? softDeletes,
    StrictnessConfig? strictness,
    Environment? environment,
  }) => WormConfig(
    defaultConnection: defaultConnection ?? this.defaultConnection,
    connections: connections ?? this.connections,
    poolSize: poolSize ?? this.poolSize,
    primaryKeyType: primaryKeyType ?? this.primaryKeyType,
    timestamps: timestamps ?? this.timestamps,
    softDeletes: softDeletes ?? this.softDeletes,
    strictness: strictness ?? this.strictness,
    environment: environment ?? this.environment,
  );
}
