# Changelog

All notable changes to this package are documented in the
[root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). The
`beak_*` packages are versioned in lockstep, so one entry there covers all of
them.

## 0.9.0 - Unreleased

The S3 / MinIO storage driver.

New in 0.9.0: the S3 client is built into the package (`HttpS3ObjectClient`, AWS Signature Version 4 over `package:http`), so `package:minio` and the `xml` dependency override are gone. `MinioS3ObjectClient` is renamed; the root changelog lists the breaking changes.

Beak is pre-1.0: the API is not frozen, the wire format is. See
[Upgrading](https://simonerich.github.io/beak/start-here/upgrading/) for how to
move between versions.
