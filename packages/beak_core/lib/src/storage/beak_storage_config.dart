/// The sealed storage-configuration family. Part-files per driver keep each
/// config in its own file while satisfying `sealed`'s same-library rule.
library;

import 'package:meta/meta.dart';

part 'drivers/beak_ftp_config.dart';
part 'drivers/beak_local_disk_storage_config.dart';
part 'drivers/beak_memory_storage_config.dart';
part 'drivers/beak_s3_config.dart';

/// Selects and configures the storage driver at app init: pure data,
/// including credentials, consumed by the matching `BeakStorageDriver`
/// factory via `BeakStorageRegistry.resolve`.
///
/// The hierarchy is sealed so driver factories narrow with exhaustive
/// pattern matching. Configs carrying secrets redact them in [toString].
@immutable
sealed class BeakStorageConfig {
  const BeakStorageConfig();

  /// Identifier of the driver this config is consumed by
  /// (`'memory'`, `'local'`, `'s3'`, `'ftp'`).
  String get driverId;
}
