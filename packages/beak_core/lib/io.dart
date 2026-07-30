/// The `dart:io`-backed half of `beak_core`: storage drivers that need a real
/// filesystem.
///
/// Kept out of the `package:beak_core/beak_core.dart` barrel on purpose. That
/// barrel is imported by `beak_frontend` and therefore by every Flutter panel,
/// including web builds — and a single transitive `dart:io` import costs the
/// whole Flutter half its `platform:web` tag on pub.dev, on top of failing at
/// runtime in a browser if it were ever reached.
///
/// Import this library from server-side code only:
///
/// ```dart
/// import 'package:beak_core/io.dart';
///
/// final registry = BeakStorageRegistry()
///   ..register('local', BeakLocalDiskStorageDriver.fromConfig);
/// ```
///
/// `beak_backend`'s `createDefaultStorageRegistry()` already does exactly
/// that, so a Beak server gets the `local` driver without importing this
/// library directly.
library;

export 'src/storage/drivers/beak_local_disk_storage_driver.dart';
