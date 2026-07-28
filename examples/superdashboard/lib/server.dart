import 'package:beak/server.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

/// Builds the superdashboard's server from everything Beak resolved.
///
/// Nothing to change: 49 models, their migrations and the master seeder are
/// all discovered, and the defaults are what this demo wants.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();

/// The storage drivers this app can resolve.
///
/// `beak_backend` depends on no driver package, so an app that uploads to S3
/// declares `beak_storage_s3` and registers it here; `.env` selects it.
// --8<-- [start:beakStorageRegistry]
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}

// --8<-- [end:beakStorageRegistry]
