import '../common/beak_exception.dart';
import 'beak_storage_config.dart';
import 'beak_storage_driver.dart';
import 'drivers/beak_memory_storage_driver.dart';

/// Builds a [BeakStorageDriver] from a [BeakStorageConfig].
///
/// Implementations narrow the config with pattern matching and throw a
/// `BeakConfigurationException` when handed a foreign config type.
typedef BeakStorageDriverFactory =
    BeakStorageDriver Function(BeakStorageConfig config);

/// The app-level index of storage-driver factories, keyed by driver id.
///
/// Only the web-safe `memory` driver is pre-registered. Every other driver is
/// added at app init — `local` from `package:beak_core/io.dart` (it needs
/// `dart:io`), `s3` from `beak_storage_s3`, `ftp` from `beak_storage_ftp` — and
/// the backend resolves the driver matching the configured
/// [BeakStorageConfig.driverId]. `beak_backend`'s
/// `createDefaultStorageRegistry()` wires up `memory` and `local` for you.
///
/// ```dart
/// final registry = BeakStorageRegistry()
///   ..register('s3', S3StorageDriver.fromConfig); // from beak_storage_s3
/// // or, the same in one call: registerS3Storage(registry)
///
/// // Later, build the driver the config selects:
/// final BeakStorageDriver driver = registry.resolve(
///   BeakS3Config(
///     endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
///     bucket: 'uploads',
///     accessKey: accessKey,
///     secretKey: secretKey,
///     region: 'eu-central-1',
///   ),
/// );
/// ```
final class BeakStorageRegistry {
  /// Creates a registry with the web-safe `memory` driver registered.
  // --8<-- [start:constructor]
  BeakStorageRegistry() {
    register('memory', BeakMemoryStorageDriver.fromConfig);
  }
  // --8<-- [end:constructor]

  final Map<String, BeakStorageDriverFactory> _factoriesByDriverId = {};

  /// Registers [factory] under [driverId].
  ///
  /// Throws a [BeakConfigurationException] when the id is taken — every
  /// driver id maps to exactly one factory.
  void register(String driverId, BeakStorageDriverFactory factory) {
    if (_factoriesByDriverId.containsKey(driverId)) {
      throw BeakConfigurationException(
        'A storage driver factory for "$driverId" is already registered.',
      );
    }
    _factoriesByDriverId[driverId] = factory;
  }

  /// Builds the driver configured by [config].
  ///
  /// Throws a [BeakConfigurationException] when no factory is registered
  /// for [BeakStorageConfig.driverId] — typically a missing driver package
  /// registration.
  // --8<-- [start:resolve]
  BeakStorageDriver resolve(BeakStorageConfig config) {
    final BeakStorageDriverFactory? factory =
        _factoriesByDriverId[config.driverId];
    if (factory == null) {
      throw BeakConfigurationException(
        'No storage driver is registered for "${config.driverId}". '
        'Registered drivers: ${driverIds.join(', ')}.',
      );
    }
    return factory(config);
  }
  // --8<-- [end:resolve]

  /// Every registered driver id, in registration order.
  List<String> get driverIds => List.unmodifiable(_factoriesByDriverId.keys);
}
