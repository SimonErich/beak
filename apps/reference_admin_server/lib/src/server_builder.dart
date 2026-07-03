import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:reference_admin_models/reference_admin_models.dart';
import 'package:worm/worm.dart';

/// Reads the storage driver selection from [environment]
/// (`BEAK_STORAGE_DRIVER`): `s3` builds a [BeakS3Config] from the
/// `BEAK_S3_*` variables, `memory` selects the in-memory driver (tests),
/// anything absent disables uploads.
///
/// Throws a [BeakConfigurationException] when `s3` is selected but a
/// required variable is missing.
BeakStorageConfig? referenceStorageConfig(Map<String, String> environment) {
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

/// Assembles the reference [BeakServer]: the shared model registry over a
/// worm-backed data source on [adapter], with uploads enabled when
/// [storage] is configured — the whole backend from one call.
BeakServer buildReferenceServer({
  required BeakBackendConfig config,
  required DatabaseAdapter adapter,
  BeakStorageDriver? storage,
}) {
  final BeakModelRegistry registry = buildReferenceRegistry();
  return BeakServer(
    config: config,
    registry: registry,
    dataSource: WormDataSource(registry, adapter: adapter),
    storage: storage,
  );
}
