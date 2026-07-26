import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';

/// Builds a [BeakStorageRegistry] with the drivers Beak ships in-box:
/// `memory` (from `beak_core`) and `local` (from `package:beak_core/io.dart`,
/// registered here because it needs `dart:io`).
///
/// Driver *packages* are deliberately not wired in. Depending on
/// `beak_storage_s3` from here would put `minio` — and its `xml ^6` pin — in
/// the dependency graph of every Beak backend, whether or not it uploads
/// anything. Add the driver you actually use at app init instead:
///
/// ```dart
/// import 'package:beak_storage_s3/beak_storage_s3.dart';
///
/// final registry = createDefaultStorageRegistry();
/// registerS3Storage(registry);
/// final storage = resolveStorage(config, registry: registry);
/// ```
///
/// Resolving a config whose driver is not registered throws a
/// [BeakConfigurationException] naming the driver and listing the registered
/// ones, so a missing registration fails loudly at startup.
BeakStorageRegistry createDefaultStorageRegistry() {
  final registry = BeakStorageRegistry();
  registry.register('local', BeakLocalDiskStorageDriver.fromConfig);
  return registry;
}

/// Resolves the [BeakStorageDriver] the [config] selects, using [registry]
/// (default: the in-box `memory` and `local` drivers). The server resolves
/// once at startup and injects the driver into the upload service.
///
/// ```dart
/// final storage = resolveStorage(
///   BeakLocalDiskStorageConfig(
///     rootDir: 'var/uploads',
///     publicBaseUrl: Uri.parse('http://localhost:8080/files'),
///   ),
/// );
/// final server = BeakServer(
///   config: config,
///   registry: registry,
///   dataSource: dataSource,
///   storage: storage,
/// );
/// ```
///
/// Pass [registry] to resolve a driver from a plug-in package:
///
/// ```dart
/// final registry = createDefaultStorageRegistry();
/// registerS3Storage(registry); // from beak_storage_s3
/// final storage = resolveStorage(s3Config, registry: registry);
/// ```
BeakStorageDriver resolveStorage(
  BeakStorageConfig config, {
  BeakStorageRegistry? registry,
}) => (registry ?? createDefaultStorageRegistry()).resolve(config);
