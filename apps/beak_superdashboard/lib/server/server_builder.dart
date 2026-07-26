import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:worm/worm.dart';

/// The storage registry this app resolves drivers from: Beak's in-box
/// `memory` and `local` drivers plus the `s3` plug-in that `.env` selects.
///
/// `beak_backend` deliberately does not depend on any driver package, so an
/// app that uploads to S3 declares `beak_storage_s3` and registers it here.
BeakStorageRegistry demoStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}

/// Reads the storage driver from [environment] (`BEAK_STORAGE_DRIVER`): `s3`
/// builds a [BeakS3Config] from the `BEAK_S3_*` variables, `memory` selects
/// the in-memory driver (tests), absent disables uploads.
///
/// Throws a [BeakConfigurationException] when `s3` is selected but a required
/// variable is missing, or when the driver name is unknown.
BeakStorageConfig? demoStorageConfig(Map<String, String> environment) {
  switch (environment['BEAK_STORAGE_DRIVER']) {
    case 's3':
      String require(String key) {
        final String? value = environment[key];
        if (value == null || value.isEmpty) {
          throw BeakConfigurationException(
            '$key is required when BEAK_STORAGE_DRIVER=s3.',
          );
        }
        return value;
      }

      return BeakS3Config(
        endpoint: Uri.parse(require('BEAK_S3_ENDPOINT')),
        bucket: require('BEAK_S3_BUCKET'),
        accessKey: require('BEAK_S3_ACCESS_KEY'),
        secretKey: require('BEAK_S3_SECRET_KEY'),
        region: require('BEAK_S3_REGION'),
        usePathStyle: environment['BEAK_S3_USE_PATH_STYLE'] == 'true',
      );
    case 'memory':
      return const BeakMemoryStorageConfig();
    case null || '':
      return null;
    case final String other:
      throw BeakConfigurationException(
        'Unsupported BEAK_STORAGE_DRIVER "$other" (use "s3" or "memory").',
      );
  }
}

/// Assembles the superdashboard [BeakServer]: every registered model over a
/// worm-backed data source on [adapter], with uploads enabled when [storage]
/// is configured — the whole backend from one call, zero hand-written
/// endpoints.
BeakServer buildDemoServer({
  required BeakBackendConfig config,
  required DatabaseAdapter adapter,
  BeakStorageDriver? storage,
}) {
  final BeakModelRegistry registry = buildDemoRegistry();
  return BeakServer(
    config: config,
    registry: registry,
    dataSource: WormDataSource(registry, adapter: adapter),
    storage: storage,
  );
}
