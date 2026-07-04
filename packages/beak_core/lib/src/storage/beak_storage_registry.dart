import '../common/beak_exception.dart';
import 'beak_storage_config.dart';
import 'beak_storage_driver.dart';
import 'drivers/beak_local_disk_storage_driver.dart';
import 'drivers/beak_memory_storage_driver.dart';

/// Builds a [BeakStorageDriver] from a [BeakStorageConfig].
///
/// Implementations narrow the config with pattern matching and throw a
/// `BeakConfigurationException` when handed a foreign config type.
typedef BeakStorageDriverFactory =
    BeakStorageDriver Function(BeakStorageConfig config);

/// The app-level index of storage-driver factories, keyed by driver id.
///
/// The built-in `memory` and `local` drivers are pre-registered; driver
/// packages add theirs at app init (`registry.register('s3', ...)`) and the
/// backend resolves the driver matching the configured
/// [BeakStorageConfig.driverId].
///
/// ```dart
/// final registry = BeakStorageRegistry()
///   ..register('s3', BeakS3StorageDriver.fromConfig); // from beak_storage_s3
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
  /// Creates a registry with the built-in `memory` and `local` drivers
  /// registered.
  BeakStorageRegistry() {
    register('memory', BeakMemoryStorageDriver.fromConfig);
    register('local', BeakLocalDiskStorageDriver.fromConfig);
  }

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

  /// Every registered driver id, in registration order.
  List<String> get driverIds => List.unmodifiable(_factoriesByDriverId.keys);
}
