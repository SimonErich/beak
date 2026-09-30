---
title: Files and storage columns
description: Declare image and file columns with size, type and dimension rules and image transforms, plus ordered galleries, and see what the server stores.
type: guide
audience: [beginner, expert]
status: stable
---

# Files and storage columns

A product needs pictures and an invoice needs a PDF. After this page you can declare both as columns, put the rules on the column once, and tell which rule runs where, what lands in the row and what stays in storage.

## At a glance

A file column is a string column with opinions. The row holds a storage key such as `product-images/<uuid>.png`, never bytes and never a URL. The bytes live in a storage driver (local disk until you say otherwise), and the panel and the API both read the rules from the column.

| You want | Declare | Column you get | The row holds |
| --- | --- | --- | --- |
| One picture | `BeakImageRef` field, optionally `@Image(...)` | `BeakImageColumn` | The key of the stored image |
| One document | `BeakFileRef` field with `@FileField(...)` | `BeakFileColumn` | The key of the stored file |
| Several ordered pictures | A `@HasMany(owned: true)` list of rows that each have an image field | One image column per child row | One child row per picture |

`BeakImageRef` and `BeakFileRef` come from `package:beak/schema.dart`. They are extension types over `String`, so they cost nothing at runtime and exist to tell `beak prepare` which column you mean. A nullable field is an optional upload, a non-nullable field gets `BeakRequired()` like any other column.

This is the shop's gallery row:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_image.dart"
```

`beak prepare` turns the `image` field into this column. Everything from the annotation is copied over, and the required rule comes from the field being non-nullable:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.beak.dart"
  /// The uploaded original and automatic thumbnail.
  static const BeakImageColumn image = BeakImageColumn(
    key: 'image',
    label: 'Image',
    rules: [BeakRequired()],
    storagePath: 'product-images',
    maxSizeInBytes: 10485760,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg, BeakFileType.webp],
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions.square(480),
        name: 'thumbnail',
      ),
    ],
  );
```

`ProductImageRecord.image` reads back as a `String`, the key. The shop has no file column, so the showcase's `Specimen` shows the other annotation next to an image:

```dart
--8<-- "examples/showcase/lib/resources/specimens/models/specimen.dart:SpecimenUploads"
```

## Declare the column

`@Image` and `@FileField` share three parameters, and `@Image` adds the four that only make sense for pixels.

| Parameter | On | Default | Meaning |
| --- | --- | --- | --- |
| `storagePath` | both | required | Folder inside the storage driver. Keys start with it. |
| `maxSizeInBytes` | both | 100 MiB | Largest accepted upload. A column that sets none is held to 100 MiB, because the body is read into memory. |
| `allowedTypes` | both | `@Image`: `jpeg`, `png`, `webp`, `gif`. `@FileField`: any | Accepted `BeakFileType` values. |
| `maxDimensions` | `@Image` | none | Largest accepted width and height in pixels. |
| `aspectRatio` | `@Image` | none | Required width divided by height, within 0.01. |
| `transforms` | `@Image` | none | Steps run on upload, in order. |
| `thumbnail` | `@Image` | none | Accepted and ignored, see below. |

The full list is on [Annotations](../reference/annotations.md). `BeakFileType` covers `jpeg`, `png`, `webp`, `gif`, `svg`, `pdf`, `csv`, `json`, `zip`, `mp4` and `mp3`. SVG is not in the image default because it can carry scripts, and an image column could not transform it anyway.

A `BeakImageRef` or `BeakFileRef` field with no annotation is still an upload column. Its `storagePath` is the table name and an image column still gets the image default for `allowedTypes`. What does not work is an annotation with no `storagePath`: the constructor requires one, so `beak prepare` reports a bare `@Image()` or `@FileField(maxSizeInBytes: 1024)` and generates nothing until you fix it.

```text
Cannot generate: fix these first:
  lib/models/document.dart: Document.cover: @Image needs a storagePath, the folder its uploads land in. Write @Image(storagePath: 'documents'), or drop the annotation to use the table name.
```

Write `@Image(storagePath: 'covers')`, or drop the annotation and take the table name.

!!! warning "thumbnail: does nothing"
    `@Image(thumbnail: BeakDimensions.square(64))` is accepted and stored on the column, and no code reads it. The upload comes back with `"variants": {}`. A rendition exists only when a `BeakThumbnailTransform` sits in `transforms`.

## What the rules do, and where

A rule on the column runs in two places, and the second one is the one that counts. The panel checks size and type before it accepts a file, so an oversize PDF fails on the spot. Dimensions and aspect ratio need the image header, so only the server runs them.

| Rule | Panel, when the file is picked | Server, at upload | Error key |
| --- | --- | --- | --- |
| `maxSizeInBytes` | Yes | Yes, while the body streams in, so an oversize file is never buffered whole | `size` |
| `allowedTypes` | Yes | Yes. The declared MIME type and the file extension must each be on the list | `type` |
| `maxDimensions` | No | Yes, from the image header, before any decode | `dimensions` |
| `aspectRatio` | No | Yes, from the image header, before any decode | `aspectRatio` |

Violations come back together, one message list per key, as a `422`:

```json
{"code":"validation","message":"The upload \"wide.png\" failed validation.","fieldErrors":{"dimensions":["The image is 2500x100 pixels, exceeding the limit of 2000x2000 pixels."]}}
```

Two behaviours are worth knowing before you rely on a rule:

- An image column reads the bytes first. The server reads the header as PNG, JPEG, WebP or GIF before it looks at the type list. A text file sent to an image column is refused with `The uploaded file is not a supported raster image`, not with a `type` error. A real GIF into a PNG and JPEG column does get the `type` error. A file with a valid header and damaged content (truncated, corrupt) is refused with `The uploaded file could not be decoded as an image`.
- A file column trusts the label. `BeakFileColumn` checks the size and the declared MIME type and extension, and nothing else. It does not read the bytes. PNG bytes uploaded as `x.pdf` with `Content-Type: application/pdf` are stored as a PDF. If people you do not trust upload files, put a scanner behind the bucket.

## Transforms

`transforms` is an ordered pipeline that runs on the server after the checks pass. The spec lives in `beak_core`; the pixels are handled by `ImageTransformRunner` in `packages/beak_image`, which the server uses unless you hand it another `BeakTransformRunner`.

| Step | Parameters | What it does |
| --- | --- | --- |
| `BeakResizeTransform` | `widthInPixels`, `heightInPixels`, `fit` (`contain` by default, `cover`, `fill`) | Scales the image. With one dimension given the aspect ratio is kept. |
| `BeakFormatTransform` | `format` (`jpg`, `png`, `webp`), `quality` 0 to 100, default 80. `.webp()` is the shorthand | Re-encodes. Quality applies to JPEG only, because the WebP encoder is lossless. |
| `BeakThumbnailTransform` | `size`, `name` (default `thumbnail`) | Adds a second stored file, cover-cropped to exactly `size`. Names must be unique. |

Order matters. A thumbnail sees the image as it is at that point in the pipeline, and is encoded in the format the pipeline has reached by then. Put the resize first if the thumbnail should come from the resized picture.

With no steps, the source bytes are stored untouched. With any step, the main image is re-encoded, even when the only step is a thumbnail. The runner accepts PNG, JPEG, WebP and GIF, and a GIF that goes through a step keeps only its first frame.

The upload answers with a `BeakStoredFile`. This one comes from the scratch `Document.cover` column in [Verify it](#verify-it), an image column with a 120 pixel thumbnail (reformatted, the server sends one line):

```json
{
  "key": "covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd.png",
  "url": "http://localhost:28617/uploads/covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd.png",
  "sizeInBytes": 638,
  "mimeType": "image/png",
  "widthInPixels": 300,
  "heightInPixels": 200,
  "variants": {
    "thumbnail": {
      "key": "covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd_thumbnail.png",
      "url": "http://localhost:28617/uploads/covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd_thumbnail.png",
      "widthInPixels": 120,
      "heightInPixels": 120
    }
  }
}
```

The key is `<storagePath>/<uuid>.<extension>`, and a rendition is `<uuid>_<name>.<extension>`. The server mints the uuid and takes the extension from the stored MIME type. The name of the file the user picked never reaches storage.

!!! note "The row keeps one key"
    The column stores the main image's key. The renditions sit beside it in storage and no column records their keys. A reloaded panel shows the main file everywhere (40 pixels in a table cell, 160 in a detail page), and the thumbnail is used only for the preview of a file uploaded in the same form session. Cap the main image with a resize step if a 10 MB original in a 40 pixel cell bothers you, and read `<uuid>_thumbnail.<extension>` from your own API clients if they want the small one.

## From picker to row

In a form screen the panel does not upload when the user picks a file. It stages the bytes in the form draft, and the upload happens when the whole form is valid and Save begins.

1. Pick. The platform picker hands over name, type and bytes. The panel checks size and type, keeps the bytes in memory under a local `beak-draft:` key and previews them from a `data:` URL. Nothing has left the browser.
2. Edit. Replacing or removing a selection drops its bytes. No request is made for a file that is not in the final form.
3. Save. After form validation, every staged file that the save still references goes to `POST /api/{table}/{columnKey}/upload`, the plan's local keys are swapped for the returned storage keys, and the graph goes out as one commit. Rules only the server can check, dimensions and aspect ratio, fail here, as a form error on Save.
4. Retry, adopt, discard. A failed save keeps the files it already uploaded and reuses them on retry. A confirmed save adopts them. Cancelling the form deletes the files that draft uploaded, with their renditions, when the save is known not to have committed. When the outcome is unknown the files stay until receipt recovery settles it.

A resumable draft, when a screen enables them, stores no file bytes. The panel says `Select any uncommitted files again`.

To pick from a camera or an asset library, or to send uploads through another transport, set `filePicker` or `uploader` on the `BeakResource`. A picker is this shape:

```dart
--8<-- "packages/beak_frontend/lib/src/form/upload_field.dart:BeakFilePicker"
```

Storage and the database are two systems, and Beak does not pretend otherwise. A crash between the upload and the commit leaves a file no row points at. Deleting a row, or replacing its key, does not delete the file either, because another record may still use that key, and a soft-deleted row can be restored with its file. Expire old unreferenced files with a job that checks references first.

## Galleries

One picture per column does not scale to a product gallery. Model it as owned child rows, each with an image, a caption and a position, and place them with `galleryForm`:

```dart
--8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:productGallery"
```

The gallery shows a card per picture with the image input, the caption and move controls, and the first position is the cover. Moving a card rewrites the positions in the local draft, and the pictures, captions and order save with the parent in the same commit. Removing a card deletes the owned row on Save; the stored file stays, as above.

`galleryForm` refuses a wrong setup when the form layout is built:

| Mistake | `BeakConfigurationException` |
| --- | --- |
| The relationship is not `@HasMany(owned: true)` | `A gallery needs an owned has-many relationship.` |
| `image` is not an image column | `The gallery image must be an image column.` |
| A field belongs to another model | `Gallery fields must belong to its child model.` |

An unowned list is refused on purpose. Removing a card from a shared list would delete media that another record owns. The relationship side of this is on [Relationships](relationships.md), the form side on [Uploads and galleries](../forms/uploads-and-galleries.md).

## Where files land

You do not configure storage on the column. The server picks a driver from the environment:

| `BEAK_STORAGE_DRIVER` | Files go to |
| --- | --- |
| unset | Local disk under `storage/uploads`, served by the same server at `/uploads` |
| `local`, `memory` | Local disk at a root you name, or memory for tests |
| `s3`, `ftp` | A bucket or an FTP server. Register the driver package in `beakStorageRegistry()` in `lib/server.dart` first |
| `none` | Nowhere. The upload routes are not mounted |

That default is why a fresh project can upload with no setup, the same way it uses a SQLite file until `DATABASE_URL` says otherwise. [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) lists the variables, [Storage internals](../architecture/storage-internals.md) shows how a config becomes a driver, and [Custom storage drivers](../extending/custom-storage-drivers.md) covers writing your own.

## Reading a file back

A stored key becomes a URL through `GET /api/{table}/{columnKey}/upload?key=`. The route checks read permission and field access, applies row scope (a hidden record does not reveal its files), and refuses keys outside the column's `storagePath`. The panel calls it for you when it draws an image cell or a form preview.

- Images render in tables and detail pages through that route.
- Files have no built-in cell. A table, a detail page and a read-only form show `Unavailable` for a `BeakFileColumn`, whatever it holds. The form does have the picker. To show a download link today, draw it in a custom block or screen and resolve the key yourself.
- URLs are signed where the driver can sign. The server asks the driver for a link that expires after `signedUrlLifetime` (one hour by default, `defaults.build(signedUrlLifetime: ...)`), so an S3 driver answers with a presigned URL and a private bucket works (a configured public base URL is answered instead). The `url` a fresh upload returns is the plain public URL, and the panel resolves a key again when it draws it. A local-disk URL never expires and is served by a route with no policy, so authorizing the lookup does not make it private.

## Rules and limits

- The row stores whatever string the write carries. Only the upload endpoints check keys. A record write does not confirm that the key exists, sits under the column's `storagePath` or was uploaded by the caller, so a client that may write the row can point it at any string. Resolving such a key through the upload route still refuses anything outside the prefix.
- Access to files is decided by the table and column policies ([Auth and policies](../backend/auth-and-policies.md)). The `storagePath` prefix only keeps one column's keys out of another column's routes.
- Size limits count the uploaded, compressed bytes. The dimension limit is checked after decoding, so a small file that expands into a huge bitmap costs memory before it is refused. Set both on every image column.
- Renaming a `storagePath` after files exist strands them: resolving and deleting refuse keys that do not start with the new path.
- `svg` can be listed in an image column's `allowedTypes`, but the runner cannot decode it and every upload is refused. Use `@FileField` for SVG.
- Beak deletes files only for uploads an abandoned draft made. A row or a key that goes away leaves its file behind, see "From picker to row".

## Verify it

The transcript comes from a scratch project with this model. It is illustrative, and every name in it is real API:

```dart
@Resource()
final class Document extends BeakSchema {
  @Display()
  late final String title;

  @Image(
    storagePath: 'covers',
    maxSizeInBytes: 1048576,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg],
    maxDimensions: BeakDimensions(widthInPixels: 2000, heightInPixels: 2000),
    transforms: [BeakThumbnailTransform(size: BeakDimensions.square(120))],
  )
  late final BeakImageRef? cover;

  @FileField(
    storagePath: 'contracts',
    maxSizeInBytes: 2097152,
    allowedTypes: [BeakFileType.pdf],
  )
  late final BeakFileRef? contract;

  late final BeakImageRef? logo;
}
```

Generate, analyze, migrate and start the API. The default port is 8080, and the transcript ran on 28617 because 8080 was taken, so its URLs carry that port.

```bash
beak prepare
dart analyze
beak migrate
beak dev
```

Upload through the route the panel uses. The requests send a passing cover, an image wider than `maxDimensions`, a GIF the column does not allow, a text file, PNG bytes labelled as a PDF, and a bare `BeakImageRef`:

```bash
API=http://localhost:8080
curl -s -X POST -F 'file=@cover.png;type=image/png' $API/api/documents/cover/upload
curl -s -X POST -F 'file=@wide.png;type=image/png' $API/api/documents/cover/upload
curl -s -X POST -F 'file=@dot.gif;type=image/gif' $API/api/documents/cover/upload
curl -s -X POST -F 'file=@notes.txt;type=text/plain' $API/api/documents/cover/upload
curl -s -X POST -F 'file=@cover.png;type=application/pdf;filename=x.pdf' $API/api/documents/contract/upload
curl -s -X POST -F 'file=@cover.png;type=image/png' $API/api/documents/logo/upload
```

```text
{"key":"covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd.png", ... ,"variants":{"thumbnail":{ ... }}}   201
{"code":"validation","message":"The upload \"wide.png\" failed validation.","fieldErrors":{"dimensions":["The image is 2500x100 pixels, exceeding the limit of 2000x2000 pixels."]}}   422
{"code":"validation","message":"The upload \"dot.gif\" failed validation.","fieldErrors":{"type":["The MIME type \"image/gif\" is not allowed.","The file extension \".gif\" is not allowed."]}}   422
{"code":"validation","message":"The uploaded file is not a supported raster image (PNG, JPEG, WebP or GIF)."}   422
{"key":"contracts/d66a860c-48be-47b0-9282-85709a64ef23.pdf", ... ,"mimeType":"application/pdf", ... }   201
{"key":"documents/b8b00180-ad1a-4956-b020-d7901d5083df.png", ... ,"variants":{}}   201
```

The `requestId` fields and the middle of the long lines are trimmed, and the status codes are appended. The last request is the unannotated field: its key starts with the table name and it gets no rendition, because it has no transforms.

Resolve a key, refuse a key from another column, delete a key and resolve it again:

```bash
curl -s "$API/api/documents/logo/upload?key=documents/b8b00180-ad1a-4956-b020-d7901d5083df.png"
curl -s "$API/api/documents/logo/upload?key=covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd.png"
curl -s -X DELETE -H 'content-type: application/json' \
  -d '{"key":"documents/b8b00180-ad1a-4956-b020-d7901d5083df.png"}' $API/api/documents/logo/upload
curl -s "$API/api/documents/logo/upload?key=documents/b8b00180-ad1a-4956-b020-d7901d5083df.png"
```

```text
{"url":"http://localhost:28617/uploads/documents/b8b00180-ad1a-4956-b020-d7901d5083df.png"}   200
{"code":"validation","message":"Key \"covers/a40c60cc-74a3-44b5-9cdc-8cb165e198cd.png\" does not belong to column \"logo\" (expected the \"documents/\" prefix)."}   422
(empty)   204
{"code":"not_found","message":"No stored file \"documents/b8b00180-ad1a-4956-b020-d7901d5083df.png\"."}   404
```

The staging and cleanup rules and the gallery guards have tests:

```bash
cd packages/beak_frontend
flutter test test/src/form/beak_draft_uploads_test.dart test/src/form/beak_gallery_test.dart
cd ../beak_core
dart test test/src/storage
```

## Reference

| Symbol | Package | Purpose |
| --- | --- | --- |
| `BeakImageRef`, `BeakFileRef` | `package:beak/schema.dart` | Field types that select an upload column |
| `@Image`, `@FileField` | `package:beak/schema.dart` | Storage path and file rules, see [Annotations](../reference/annotations.md) |
| `BeakImageColumn`, `BeakFileColumn` | `package:beak/beak.dart` | The generated columns, see [Field types](../reference/field-types.md) |
| `BeakFileType`, `BeakDimensions` | `package:beak/beak.dart` | Accepted types and pixel sizes |
| `BeakResizeTransform`, `BeakFormatTransform`, `BeakThumbnailTransform` | `package:beak/beak.dart` | The transform steps |
| `BeakUploadValidator` | `package:beak/beak.dart` | Size, type, dimension and ratio checks, shared by client and server |
| `BeakStoredFile`, `BeakStoredFileVariant` | `package:beak/beak.dart` | What an upload returns |
| `galleryForm`, `BeakGallery` | `package:beak/panel.dart` | Ordered owned image rows |
| `BeakResource.filePicker`, `BeakResource.uploader` | `package:beak/panel.dart` | Replace the picker or the transport |
| `POST`, `GET`, `DELETE /api/{table}/{columnKey}/upload` | REST | Store, resolve and remove, see [REST API](../reference/rest-api.md) |

Sources: `packages/beak_core/lib/src/storage`, `packages/beak_backend/lib/src/uploads` and `packages/beak_frontend/lib/src/form/beak_draft_uploads.dart`.

## Continue reading

- [Uploads and galleries](../forms/uploads-and-galleries.md) puts uploads and galleries into a form screen.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) selects and configures the storage driver.
- [Custom storage drivers](../extending/custom-storage-drivers.md) implements `BeakStorageDriver` for a backend Beak does not ship.
- [Dynamic attributes and variants](dynamic-attributes-and-variants.md) is the next model guide.
