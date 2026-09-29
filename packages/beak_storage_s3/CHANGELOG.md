# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

The S3 / MinIO storage driver.

The S3 client is now built into the package: `HttpS3ObjectClient` speaks S3's
REST API over `package:http` and signs each request with AWS Signature Version
4, checked against the published AWS test vectors and MinIO. `package:minio` is
gone from the dependency graph, and with it the `xml ^6` pin that made a project
depending on both `beak` and `beak_storage_s3` need
`dependency_overrides: xml: ^7.0.1`. That override is no longer needed.

Breaking (pre-1.0): `MinioS3ObjectClient` is renamed `HttpS3ObjectClient`, its
`minio:` constructor parameter is replaced by `httpClient:` and `clock:`, and a
failing response now throws the new `S3ResponseException` (status, S3 error code,
message) instead of a `package:minio` error. `S3StorageDriver` still wraps every
failure in a `BeakStorageException`.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
