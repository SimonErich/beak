/// S3/MinIO storage driver for Beak's storage abstraction.
///
/// Plugs an S3-compatible driver (AWS S3, MinIO, ...) into `beak_core`'s
/// storage layer. Call [registerS3Storage] once at startup so a
/// `BeakStorageRegistry` resolves any `BeakS3Config` to an [S3StorageDriver];
/// nothing is hard-wired into core.
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_storage_s3/beak_storage_s3.dart';
///
/// final registry = BeakStorageRegistry();
/// registerS3Storage(registry);
///
/// final driver = registry.resolve(BeakS3Config(
///   endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
///   bucket: 'uploads',
///   accessKey: '...',
///   secretKey: '...',
///   region: 'eu-central-1',
/// ));
/// ```
///
/// [S3ObjectClient] is the wire seam the driver speaks through; production
/// code uses [MinioS3ObjectClient], and tests substitute a fake.
library;

export 'src/s3_object_client.dart';
export 'src/s3_storage_driver.dart';

/// The version of the `beak_storage_s3` package.
const String beakStorageS3Version = '0.9.0';
