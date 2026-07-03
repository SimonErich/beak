import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_ftp/beak_storage_ftp.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

/// A storage registry with every built-in driver: `memory` and `local`
/// (from beak_core) plus `s3` and `ftp` (registered here — the driver
/// packages plug in, nothing is hard-wired into core).
BeakStorageRegistry createDefaultStorageRegistry() {
  final registry = BeakStorageRegistry();
  registerS3Storage(registry);
  registerFtpStorage(registry);
  return registry;
}

/// Resolves the driver [config] selects, using [registry] (default: every
/// built-in driver). The server resolves once at startup and injects the
/// driver into the upload service.
BeakStorageDriver resolveStorage(
  BeakStorageConfig config, {
  BeakStorageRegistry? registry,
}) => (registry ?? createDefaultStorageRegistry()).resolve(config);
