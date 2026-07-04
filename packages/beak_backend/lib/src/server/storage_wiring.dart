import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_ftp/beak_storage_ftp.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

/// Builds a [BeakStorageRegistry] with every built-in driver: `memory` and
/// `local` (from beak_core) plus `s3` and `ftp` (registered here — the driver
/// packages plug in, nothing is hard-wired into core).
///
/// Extend the returned registry with a custom driver before resolving, or
/// pass your own registry to [resolveStorage].
BeakStorageRegistry createDefaultStorageRegistry() {
  final registry = BeakStorageRegistry();
  registerS3Storage(registry);
  registerFtpStorage(registry);
  return registry;
}

/// Resolves the [BeakStorageDriver] the [config] selects, using [registry]
/// (default: every built-in driver). The server resolves once at startup and
/// injects the driver into the upload service.
///
/// ```dart
/// final storage = resolveStorage(
///   BeakS3Config(
///     endpoint: Uri.parse('https://s3.example.com'),
///     bucket: 'uploads',
///     accessKey: accessKey,
///     secretKey: secretKey,
///     region: 'us-east-1',
///   ),
/// );
/// final server = BeakServer(
///   config: config,
///   registry: registry,
///   dataSource: dataSource,
///   storage: storage,
/// );
/// ```
BeakStorageDriver resolveStorage(
  BeakStorageConfig config, {
  BeakStorageRegistry? registry,
}) => (registry ?? createDefaultStorageRegistry()).resolve(config);
