import 'package:beak/server.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

/// Builds the API this app exposes.
///
/// Beak's own server is unchanged; what differs is that the host mounts it
/// (see `bin/host.dart`) rather than being it.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();

/// The storage drivers this app can resolve.
///
/// `beak_backend` depends on no driver package on purpose, so an app that
/// uploads to S3 declares `beak_storage_s3` and registers it here. Set
/// `BEAK_STORAGE_DRIVER=s3` and the rest of the `BEAK_S3_*` variables, and
/// every upload column stores there instead of on local disk.
// --8<-- [start:beakStorageRegistry]
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}

// --8<-- [end:beakStorageRegistry]
