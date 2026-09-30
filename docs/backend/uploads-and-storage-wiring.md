---
title: Uploads and storage wiring
description: Turn a file column into an upload endpoint, choose where the bytes land with one environment variable, and know what each driver needs to boot.
type: guide
audience: [expert]
status: stable
---

# Uploads and storage wiring

A file or image column becomes an upload endpoint without any code on the server. After this page you can turn uploads on, off or over to S3, name what each storage driver needs to boot, and predict what a rejected upload answers.

The column side (rules, dimensions, transforms) is [Files and storage columns](../models/files-and-storage-columns.md). How the service and drivers are built is [Storage internals](../architecture/storage-internals.md). This page is the wiring between them: the routes, the variables, and the failures you meet on the way to production.

## At a glance

| You want | Do |
| --- | --- |
| Uploads on a fresh project | Nothing. A file column stores under `storage/uploads` and the server serves it at `/uploads` |
| No upload endpoints | `BEAK_STORAGE_DRIVER=none` |
| Files on a chosen disk and URL | `BEAK_STORAGE_DRIVER=local` with `BEAK_LOCAL_ROOT_DIR` and `BEAK_LOCAL_PUBLIC_BASE_URL` |
| Files in S3 or MinIO | Add `beak_storage_s3`, register it in `lib/server.dart`, set `BEAK_STORAGE_DRIVER=s3` and the `BEAK_S3_*` variables |
| Files over FTP | The same with `beak_storage_ftp` and the `BEAK_FTP_*` variables |
| No files at all in a test | `BEAK_STORAGE_DRIVER=memory` |

## Declare a column, get three routes

The shop declares one image column. The rules sit on the column, and the server enforces them:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_image.dart:productImageColumn"
```

`beak prepare` turns that into a `BeakImageColumn` on the generated model, and when the host has a storage driver, `beakApiRouter` mounts three routes on every model:

```dart title="packages/beak_backend/lib/src/uploads/upload_router.dart"
--8<-- "packages/beak_backend/lib/src/uploads/upload_router.dart:registerUploadRoutes"
```

| Route | Body | Success | Gate |
| --- | --- | --- | --- |
| `POST /api/{table}/{columnKey}/upload` | `multipart/form-data`, part named `file` | `201` with the stored file | Write access to the column, `canCreate` |
| `GET /api/{table}/{columnKey}/upload?key=...` | none | `200` `{"url": ...}` | `canView`, read access to the column, `BeakUploadReadPolicy` if the policy has one, and a visible record that references the key when the model has a row scope |
| `DELETE /api/{table}/{columnKey}/upload` | `{"key": "..."}` | `204` | Write access to the column, `canDeleteUpload` |

The routes exist on every model, whether or not it has an upload column. `{columnKey}` must name a file or image column: an unknown key is a `404`, another kind of column a `422`.

Upload a picture to a `photos` resource whose `image` column allows PNG and JPEG up to 200,000 bytes and makes a 32 pixel thumbnail:

```console
$ curl -s -w ' [%{http_code}]\n' -X POST localhost:8392/api/photos/image/upload -F "file=@pic.png;type=image/png"
{"key":"photos/a8d6a7ae-7baa-4808-aaea-24bd9c636621.png","url":"http://127.0.0.1:8392/uploads/photos/a8d6a7ae-7baa-4808-aaea-24bd9c636621.png","sizeInBytes":156,"mimeType":"image/png","widthInPixels":64,"heightInPixels":64,"variants":{"thumbnail":{"key":"photos/a8d6a7ae-7baa-4808-aaea-24bd9c636621_thumbnail.png","url":"http://127.0.0.1:8392/uploads/photos/a8d6a7ae-7baa-4808-aaea-24bd9c636621_thumbnail.png","widthInPixels":32,"heightInPixels":32}}} [201]
```

The client stores the `key` (and the variant keys) in the record's column. The server mints the key, and the client's filename never reaches it. The upload only stores bytes: nothing is attached to a record until a save writes the key into one.

### How a request fails

Every rule fails as a `422` that names the rule, and the rest as the usual envelope:

| Request | Answer |
| --- | --- |
| Bigger than the column's `maxSizeInBytes` | `422` `Upload rejected.` with `fieldErrors.size`. The read stops as soon as the limit is passed, so the file is never buffered whole |
| A MIME type the column does not allow | `422` `The upload "pic.png" failed validation.` with `fieldErrors.type`: `The MIME type "image/gif" is not allowed.` |
| An image column and bytes that are not a raster image | `422` `The uploaded file is not a supported raster image (PNG, JPEG, WebP or GIF).` |
| An image that has a valid header and damaged content (truncated, corrupt) | `422` `The uploaded file could not be decoded as an image.` |
| Dimensions or aspect ratio outside the column's limits | `422` with `fieldErrors.dimensions` or `aspectRatio` |
| Not `multipart/form-data` | `422` `Upload requests must be multipart/form-data with a "file" field.` |
| A multipart body with no `file` part | `422` `The multipart body has no "file" field.` |
| A column that stores no file | `422` `Column "caption" of "photos" is a BeakStringColumn; uploads need a file or image column.` |
| A key outside the column's `storagePath`, or with `..`, a backslash or a control character in it | `422` `Key "other/x.png" does not belong to column "image" (expected the "photos/" prefix).` |
| A key with no stored file | `404` `No stored file "..."` |
| The driver fails | `500` `storage` `File storage failed.` The driver's message goes to `onUnexpectedError`, not to the caller |

An image column reads the dimensions from the file header first (nothing is decoded yet), validates size, type, dimensions and aspect ratio against them, and only then decodes the image once to run the transforms and store the original with its variants. The runner also refuses any image that declares more than 50 million pixels, whatever the column says. If a variant cannot be written, the files already stored for that upload are deleted before the error goes out. A plain file column checks the size and the declared type and looks inside nothing.

`DELETE` removes exactly the key it is given. An image and its thumbnail are separate keys, so removing an upload takes one call per rendition, which is what `BeakClient.discardUpload` does. Deleting a record does not delete its files, on purpose: a soft-deleted record can be restored with its file, and another record may point at the same key. Nothing collects the orphans of an upload that was never saved either. Clean the storage on your own schedule.

## Turn uploads on, off or elsewhere

There is nothing to turn on. The host resolves a driver at boot, and with nothing configured that driver is local disk:

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_serve_host.dart:resolveStorageDriver"
```

`BEAK_STORAGE_DRIVER` picks another one, and an incomplete or unknown value stops the boot with one line that names the fix (exit `78`, the same as any other configuration failure, see [Running the server](running-the-server.md#rules-and-limits)):

```console
$ BEAK_STORAGE_DRIVER=s3 dart run bin/serve.dart
error: BEAK_S3_ENDPOINT is required when BEAK_STORAGE_DRIVER=s3.
$ BEAK_STORAGE_DRIVER=s4 dart run bin/serve.dart
error: Unsupported BEAK_STORAGE_DRIVER "s4": use one of s3, ftp, memory, local, none.
```

The variables each driver reads:

| Driver | Variables | Needs a package |
| --- | --- | --- |
| `local` | `BEAK_LOCAL_ROOT_DIR`, `BEAK_LOCAL_PUBLIC_BASE_URL`, both required | No, it is in the box |
| `s3` | `BEAK_S3_ENDPOINT`, `BEAK_S3_BUCKET`, `BEAK_S3_ACCESS_KEY`, `BEAK_S3_SECRET_KEY`, `BEAK_S3_REGION` required; `BEAK_S3_USE_PATH_STYLE=true` for MinIO and path-style hosts; `BEAK_S3_PUBLIC_BASE_URL` for a CDN in front of the bucket | `beak_storage_s3` |
| `ftp` | `BEAK_FTP_HOST`, `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD`, `BEAK_FTP_BASE_DIR`, `BEAK_FTP_PUBLIC_BASE_URL` required; `BEAK_FTP_PORT`, default `21` | `beak_storage_ftp` |
| `memory` | none | No. Files vanish with the process, and the URL is `memory:///photos/...` |
| `none` | none | No. No upload routes are mounted |

[Environment and config](../shipping/environment-and-config.md) explains how `.env` and the process environment combine.

### Local disk

Unset or `local`, the server serves the files itself. With nothing set, the root is `storage/uploads` and the route is `/uploads`. With `local`, the route is the path of `BEAK_LOCAL_PUBLIC_BASE_URL`, and the default route disappears:

```console
$ BEAK_STORAGE_DRIVER=local BEAK_LOCAL_ROOT_DIR=/data/uploads \
    BEAK_LOCAL_PUBLIC_BASE_URL=http://localhost:8392/files dart run bin/serve.dart
$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8392/files/photos/08280364-2bcd-4c9a-8eca-2c9b1dad3dc9.png
200
$ curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8392/uploads/photos/x.png
404
```

Point `BEAK_LOCAL_PUBLIC_BASE_URL` at a CDN or the web server and the server's own route is unused. The route is public and read-only. The unset default builds URLs from the bind address, where `0.0.0.0` becomes `localhost`, so choose the driver explicitly on a real host, see [Environment and config](../shipping/environment-and-config.md#the-default-url-points-at-localhost).

### S3 and MinIO

`beak_backend` depends on no driver package, so a server that never uploads to S3 does not carry the S3 driver. A project that wants S3 adds the package, registers it, and sets the variables. Three steps:

```yaml
# Illustrative: pubspec.yaml additions for the S3 driver.
dependencies:
  beak_storage_s3:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_storage_s3
```

```dart
// Illustrative: lib/server.dart. The file needs no beakServer function for this.
import 'package:beak/server.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
```

Run `beak prepare` so the generated host passes the function on, then set the variables. Against a local MinIO:

```console
$ BEAK_STORAGE_DRIVER=s3 BEAK_S3_ENDPOINT=http://localhost:28590 BEAK_S3_BUCKET=beak-uploads \
    BEAK_S3_ACCESS_KEY=beak BEAK_S3_SECRET_KEY=beaksecret BEAK_S3_REGION=us-east-1 \
    BEAK_S3_USE_PATH_STYLE=true dart run bin/serve.dart
$ curl -s -X POST localhost:8392/api/photos/image/upload -F "file=@pic.png;type=image/png"
{"key":"photos/7ed20c4d-e64b-4234-b555-fc01e455b0b9.png","url":"http://localhost:28590/beak-uploads/photos/7ed20c4d-e64b-4234-b555-fc01e455b0b9.png", ... }
```

Without the registration, the boot fails by name:

```console
error: No storage driver is registered for "s3". Registered drivers: memory, local.
```

The bucket must exist, and its policy decides whether the URL in the upload response opens. The upload returns the plain object URL. The reference stack creates its bucket with anonymous download, so those URLs open. A private bucket answers that URL with `403`. The resolve route (`GET .../upload?key=`) asks the driver for a link that expires after `signedUrlLifetime` and answers with a presigned one, so use it for a private bucket. With `BEAK_S3_PUBLIC_BASE_URL` set, for a CDN or proxy that authorizes reads, both routes answer with that public address instead.

### FTP

The same shape with `beak_storage_ftp` and `registerFtpStorage(registry)`, and the variables from the table. FTP has no expiring links, so the URL is the `BEAK_FTP_PUBLIC_BASE_URL` plus the key. This page did not run an FTP server, and the package's own tests use a small in-process one.

### A driver of your own, or a data source of your own

`defaults.build(storage: MyStorageDriver())` in `lib/server.dart` serves uploads through your own `BeakStorageDriver`, and `defaults.build(dataSource: MyDataSource())` serves the API from a source that is not worm. The driver interface is in [Custom storage drivers](../extending/custom-storage-drivers.md), the data source one in [Custom data sources](../extending/custom-data-sources.md).

## Rules and limits

| Rule | Consequence |
| --- | --- |
| The default driver is local disk with URLs built from the bind address | Fine on your machine, wrong behind a proxy. Choose the driver and its public URL explicitly |
| Uploads are validated, not authorized by content | The MIME type and extension are what the client declared. A file column with no `allowedTypes` stores `evil.html` as `<uuid>.html`. The local route serves it as a download with `x-content-type-options: nosniff` and a sandboxing `content-security-policy`, so it does not run as a page, but the file is still yours to host: list `allowedTypes`, and serve uploads from another origin. Only a short plain extension (letters and digits) is kept from the client's filename; any other suffix is dropped |
| `maxSizeInBytes` is optional, the default is 100 MiB | A column that sets none is held to 100 MiB, because the body is read into memory. Set the limit you mean on every upload column, and a larger one only where you need it |
| Images are decoded once, after the header checks | A small file can declare a very large bitmap, so `maxDimensions` is checked from the header, and `ImageTransformRunner` refuses anything above `maxPixelCount` (50 million pixels by default) before it allocates. The size limit counts compressed bytes. Only the first frame of an animated GIF is decoded |
| The resolve route signs for one hour | On a driver that signs (S3), `GET .../upload?key=` answers with a presigned link that expires after `signedUrlLifetime` (default one hour, set with `defaults.build(signedUrlLifetime: ...)`; S3 accepts one second to seven days, and a value outside that is held to it). With `BEAK_S3_PUBLIC_BASE_URL` set, the public address is answered instead. Resolve a key again instead of storing the link. Drivers with public links (local, memory, FTP) answer with the same address every time |
| A storage failure is a `500` with a generic message | The caller sees `File storage failed.` and the driver's own message (which can include an endpoint or a bucket name) goes to `onUnexpectedError`. Watch that log |
| Files outlive records | Deleting a record does not delete its files, and an abandoned upload stays. Clean up out of band |
| An unregistered driver fails at boot | `s3` and `ftp` need a package and a `beakStorageRegistry()` before the variable can select them |
| One driver per server | Every upload column stores through it. A column cannot choose its own |

## Verify it

Four requests prove the wiring: an accepted upload, the file at its URL, a rejected one, and a removal.

```console
$ curl -s -X POST localhost:8392/api/photos/image/upload -F "file=@pic.png;type=image/png"   # 201 and a key
$ curl -s -o /dev/null -w '%{http_code}\n' "$URL"                                             # 200, the file
$ curl -s -w ' [%{http_code}]\n' -X POST localhost:8392/api/photos/image/upload -F "file=@fake.png;type=image/png"
{"code":"validation","message":"The uploaded file is not a supported raster image (PNG, JPEG, WebP or GIF).","requestId":"eaf6258e8653127c"} [422]
$ curl -s -w '[%{http_code}]\n' -X DELETE localhost:8392/api/photos/image/upload -H 'content-type: application/json' -d "{\"key\":\"$KEY\"}"
[204]
```

If the second call does not answer `200` on a deployed host, the URL in the response is the problem, not the upload: check `BEAK_LOCAL_PUBLIC_BASE_URL` or the bucket policy. Then repeat the upload as a role without write access and expect a `401` or `403`, see [Auth and policies](auth-and-policies.md).

## Reference

- `packages/beak_backend/lib/src/uploads/upload_router.dart`, `upload_handler.dart`, `upload_service.dart`: the routes, the policy gates and the pipeline.
- `packages/beak_backend/lib/src/server/beak_storage_settings.dart`: `BeakStorageSettings.fromEnv`, the variables.
- `packages/beak_backend/lib/src/server/storage_wiring.dart`: `createDefaultStorageRegistry`, `resolveStorage`.
- `packages/beak_backend/lib/src/endpoints/local_uploads_router.dart`: the route that serves local files.
- [Configuration and environment](../reference/configuration.md#storage) lists the storage configs member by member.

## Continue reading

- [Files and storage columns](../models/files-and-storage-columns.md) the column side: rules, dimensions and transforms.
- [Custom storage drivers](../extending/custom-storage-drivers.md) registering a package, or writing a driver.
- [Storage internals](../architecture/storage-internals.md) how the service, the registry and the drivers fit together.
- [Security](../shipping/security.md) the upload risks to close before launch.
