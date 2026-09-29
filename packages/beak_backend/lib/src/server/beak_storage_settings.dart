import 'package:beak_core/beak_core.dart';

/// Reads the storage driver selection out of the environment.
///
/// Every Beak backend needs the same `BEAK_STORAGE_DRIVER` switch, so it
/// lives here: a project declares which drivers it supports and gets the
/// parsing, and the error wording, for free.
///
/// ```dart
/// final registry = createDefaultStorageRegistry();
/// registerS3Storage(registry); // from beak_storage_s3
///
/// final config = BeakStorageSettings.fromEnv(environment);
/// final storage = config == null ? null : resolveStorage(config, registry: registry);
/// ```
abstract final class BeakStorageSettings {
  /// Environment variable naming the driver to use.
  static const String driverKey = 'BEAK_STORAGE_DRIVER';

  /// Driver ids this parser can build a config for.
  ///
  /// A driver outside this set is still usable: register it and build its
  /// config yourself. This helper covers the ones configurable purely from
  /// environment variables. `none` is not a driver, it is the way to say
  /// that a deployment wants no upload surface at all.
  // --8<-- [start:supportedDrivers]
  static const Set<String> supportedDrivers = {
    's3',
    'ftp',
    'memory',
    'local',
    'none',
  };
  // --8<-- [end:supportedDrivers]

  /// Builds the storage config [environment] selects, or `null` when it asks
  /// for none.
  ///
  /// An unset `BEAK_STORAGE_DRIVER` selects nothing here, and the host then
  /// falls back to local disk — the same posture as the database, which is a
  /// SQLite file until `DATABASE_URL` says otherwise. `BEAK_STORAGE_DRIVER=none`
  /// is how a deployment turns uploads off outright.
  ///
  /// Throws a [BeakConfigurationException] naming the missing variable when a
  /// driver is selected without the settings it needs, and naming the
  /// supported drivers when the value is not one of them — so a typo in
  /// `.env` fails at boot with the fix in the message.
  static BeakStorageConfig? fromEnv(Map<String, String> environment) {
    String require(String key) {
      final String? value = environment[key];
      if (value == null || value.isEmpty) {
        throw BeakConfigurationException(
          '$key is required when $driverKey=${environment[driverKey]}.',
        );
      }
      return value;
    }

    switch (environment[driverKey]) {
      case 's3':
        return BeakS3Config(
          endpoint: Uri.parse(require('BEAK_S3_ENDPOINT')),
          bucket: require('BEAK_S3_BUCKET'),
          accessKey: require('BEAK_S3_ACCESS_KEY'),
          secretKey: require('BEAK_S3_SECRET_KEY'),
          region: require('BEAK_S3_REGION'),
          usePathStyle: environment['BEAK_S3_USE_PATH_STYLE'] == 'true',
          publicBaseUrl: switch (environment['BEAK_S3_PUBLIC_BASE_URL']) {
            null || '' => null,
            final String url => Uri.parse(url),
          },
        );
      case 'ftp':
        return BeakFtpConfig(
          host: require('BEAK_FTP_HOST'),
          user: require('BEAK_FTP_USER'),
          password: require('BEAK_FTP_PASSWORD'),
          baseDir: require('BEAK_FTP_BASE_DIR'),
          publicBaseUrl: Uri.parse(require('BEAK_FTP_PUBLIC_BASE_URL')),
          port: int.tryParse(environment['BEAK_FTP_PORT'] ?? '') ?? 21,
        );
      case 'local':
        return BeakLocalDiskStorageConfig(
          rootDir: require('BEAK_LOCAL_ROOT_DIR'),
          publicBaseUrl: Uri.parse(require('BEAK_LOCAL_PUBLIC_BASE_URL')),
        );
      case 'memory':
        return const BeakMemoryStorageConfig();
      case 'none' || null || '':
        return null;
      case final String other:
        throw BeakConfigurationException(
          'Unsupported $driverKey "$other" — use one of '
          '${supportedDrivers.join(', ')}.',
        );
    }
  }
}
