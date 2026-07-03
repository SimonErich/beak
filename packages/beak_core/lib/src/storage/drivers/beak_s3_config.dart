part of '../beak_storage_config.dart';

/// Configures the S3-compatible storage driver (AWS S3, MinIO, ...);
/// consumed by `beak_storage_s3`. `beak_core` owns the config
/// surface so apps configure storage without importing driver packages.
final class BeakS3Config extends BeakStorageConfig {
  /// Creates an S3 storage configuration.
  const BeakS3Config({
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    required this.region,
    this.usePathStyle = false,
    this.publicBaseUrl,
  });

  /// The S3 API endpoint, e.g. `https://s3.eu-central-1.amazonaws.com` or a
  /// MinIO host.
  final Uri endpoint;

  /// Bucket uploads are stored in.
  final String bucket;

  /// Access key id; redacted from [toString].
  final String accessKey;

  /// Secret access key; redacted from [toString].
  final String secretKey;

  /// Bucket region, e.g. `eu-central-1`.
  final String region;

  /// Whether to address the bucket path-style (`endpoint/bucket/key`) as
  /// MinIO requires, instead of AWS's virtual-host style.
  final bool usePathStyle;

  /// Public base URL overriding driver-generated file URLs (e.g. a CDN in
  /// front of the bucket); `null` lets the driver build endpoint URLs.
  final Uri? publicBaseUrl;

  @override
  String get driverId => 's3';

  @override
  String toString() =>
      'BeakS3Config(endpoint: $endpoint, bucket: $bucket, region: $region, '
      'usePathStyle: $usePathStyle, publicBaseUrl: $publicBaseUrl, '
      'accessKey: [redacted], secretKey: [redacted])';
}
