part of '../beak_storage_config.dart';

/// Configures the in-memory storage driver used in tests and prototypes;
/// it needs no settings.
final class BeakMemoryStorageConfig extends BeakStorageConfig {
  /// Creates an in-memory storage configuration.
  const BeakMemoryStorageConfig();

  @override
  String get driverId => 'memory';
}
