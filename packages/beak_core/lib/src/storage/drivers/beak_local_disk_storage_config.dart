part of '../beak_storage_config.dart';

/// Configures the local-disk storage driver: files land under [rootDir] and
/// are served from [publicBaseUrl].
final class BeakLocalDiskStorageConfig extends BeakStorageConfig {
  /// Creates a local-disk storage configuration.
  // --8<-- [start:BeakLocalDiskStorageConfig]
  const BeakLocalDiskStorageConfig({
    required this.rootDir,
    required this.publicBaseUrl,
  });
  // --8<-- [end:BeakLocalDiskStorageConfig]

  /// Directory files are written under.
  final String rootDir;

  /// Base URL stored files are publicly served from (the app serves
  /// [rootDir] there, e.g. via a static-file handler).
  final Uri publicBaseUrl;

  @override
  String get driverId => 'local';
}
