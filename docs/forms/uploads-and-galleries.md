---
title: Uploads and galleries
description: Pick files and ordered images in a form, see them staged in the draft, and know when they reach storage and what happens to them if the save fails.
type: guide
audience: [beginner, expert]
status: stable
---

# Uploads and galleries

After this page you can add an image or file field to a form, build an ordered gallery of pictures with captions, and say exactly when a chosen file leaves the browser and what becomes of it if the save fails.

The short version: choosing a file only stages its bytes in the draft. Nothing is uploaded until the whole form is valid and Save begins. That keeps a half-filled form from leaving files in storage.

## At a glance

The field is declared on the schema, and the form needs no code for a single file. `@Image` and `@FileField` carry the storage path, the accepted types, the size limit and the transforms. A picture in the shop's catalog looks like this:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_image.dart"
```

`image.input()` (or `beak prepare`'s default form) draws a Choose file button, a preview for images, the file name and Remove file. The rules on the annotation run in the form and again on the server, with the same messages.

For several pictures in a fixed order, use an owned relationship and `galleryForm`:

```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:productGallery"
```

The gallery shows each picture as a card with its preview, an editable description, any extra `metadata` inputs, move controls and Remove. The first card is the cover. Moving a card rewrites the `position` values in the draft, and the images and their positions save with the parent record in one graph commit.

## The three parts of a gallery

| Part | Declared as | Why it exists |
| --- | --- | --- |
| Child model | An owned has-many (`@HasMany(owned: true)` on the parent, `@BelongsTo` on the child) | The pictures belong to the product and go with it |
| Image field | `@Image(...)` on the child, a `BeakImageRef` | Storage rules and transforms |
| Caption and position | A string and an int on the child | Accessible description, and order |

`galleryForm` takes exactly those three fields (`image`, `caption`, `position`) plus an optional label, a `minRows`, and extra `metadata` nodes. It requires an owned has-many, three fields that belong to the child model, and an image column. A shared, unowned relationship is refused when the form is built, because removing a picture deletes its row and that row would belong to someone else.

## When bytes leave the browser

| Moment | What happens |
| --- | --- |
| Choose | The picker returns bytes. The form checks the size and the type against the column (dimension rules need decoding and stay on the server) and stages the bytes locally. The preview comes from the staged bytes, so the person sees the picture at once |
| Edit | Replacing or removing a staged file drops it. Nothing was sent, so nothing needs cleaning |
| Save | After validation passes, the session uploads every staged file that the plan still references, replaces the local keys with the final storage keys, and sends the graph. The graph never contains a local preview key |
| Failure | If the graph is rejected, the uploaded files are kept and reused on retry, without uploading twice |
| Success | A confirmed save adopts the files |
| Abandon | Closing the form deletes only the files this draft uploaded whose writes are known not to have committed. Existing files are never disposable |

If the result of a save is unknown, the uploaded files are kept until a receipt check proves the outcome. Closing the form during a save waits for the result before cleaning up. The session exposes `uploadCleanup` for a host that wants to log a cleanup failure and retry `session.uploader?.dispose()`.

A stored draft never contains file bytes, so a form resumed from a draft asks for the file again. See [Drafts, review and conflicts](drafts-and-review.md).

## What the server checks

The upload route is `POST /api/{table}/{column}/upload`, guarded by the same policy as creating a record of that resource and by the account's write access to the column. The `UploadService` validates the size, the allowed types, and for images the maximum dimensions and aspect ratio, then runs the declared transforms (the shop's `BeakThumbnailTransform` produces a `thumbnail` rendition), and stores the original and each rendition under a key it mints itself. A client filename never becomes part of a key. The response describes the stored file and its variants.

Keys are checked against the column's storage path on the way back in: a key that does not start with the column's `storagePath`, or that contains `..`, is refused.

## Showing stored files

A saved key becomes a picture through `GET /api/{table}/{column}/upload?key=`, which returns the storage driver's URL for it. The endpoint requires read access to the resource and the column, and, for a resource with a row policy, that a visible record holds the key in this exact column. Hidden and unreferenced keys both answer `404`. A policy that implements `BeakUploadReadPolicy` can add a key-specific rule.

That endpoint decides who may ask. It does not make a public file private. The local disk driver serves its files without authentication, and a public bucket stays public. The lookup asks the driver for a plain URL with no expiry, so an S3 driver returns its public URL form and never a presigned one. A private bucket therefore needs delivery of its own until that changes, see [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md).

## Replacing the picker or the transport

The native file picker is automatic. To take a photo or pick from an asset library instead, give the resource a `filePicker`, which is a function returning a `BeakUpload` or null when the person cancels:

```dart title="packages/beak_frontend/lib/src/form/upload_field.dart"
--8<-- "packages/beak_frontend/lib/src/form/upload_field.dart:BeakFilePicker"
```

`BeakResource` accepts `filePicker:` and `uploader:`. The uploader is a `BeakUploadClient`: the HTTP data source is one by default, and a custom transport implements the interface. Two optional interfaces extend it. `BeakManagedUploadClient` adds `discardUpload`, which lets an abandoned draft delete its files, and `BeakUploadUrlClient` adds `uploadUrl`, which resolves a stored key for display. A transport without the first keeps its files for whatever collection you run on the host side.

`BeakUploadField` is the widget behind a single-file placement. `BeakConfiguredForm` wires one for you. Construct it yourself only in a hand-composed form; it then uploads through its `uploader` directly instead of staging in a session.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Storage is not transactional | A crash between an upload and its save can leave an orphan file whose key the client never received. Run a maintenance job that expires old unreferenced uploads after checking record references |
| Deleting a row keeps the file | Removing a gallery row deletes the row. The physical file stays, because other records may reference the key. Collect it with the same maintenance job |
| Dimension rules are server-side | Size and type are checked in the form. `maxDimensions` and `aspectRatio` are checked by the server on upload |
| Nothing uploads early | Choosing a file never contacts storage. Staged bytes exist only in the open page |
| Bytes are not stored in drafts | A resumed draft asks for the file again |
| Gallery relationship | An owned has-many only. The child needs an image column, a string caption and an int position |
| No transport, no upload | Without an upload transport in the panel, the Choose file button is disabled. Without a storage driver on the server, the upload routes are not mounted and an upload fails |
| Private files | The URL lookup does not sign URLs today. Authorizing a lookup does not make a public URL private |
| Web images | Previews come from staged bytes or from the resolved URL. A URL the browser cannot fetch shows the image icon instead |

## Verify it

The staging, cleanup and gallery behavior has package tests:

```bash
cd packages/beak_frontend
flutter test test/src/form/beak_draft_uploads_test.dart test/src/form/beak_gallery_test.dart test/src/form/upload_field_test.dart
```

Each ends with `All tests passed!`. To see it, run the shop, open a product and its Images tab: pick two pictures, move the second up, and press Save. The order you left them in is the order the product shows.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `galleryForm`, `BeakGallery`, `BeakGalleryView` | [Input builders](../reference/input-builders.md#galleryform) |
| `@Image`, `@FileField`, `BeakFileType`, `BeakThumbnailTransform` | [Annotations](../reference/annotations.md), [Files and storage columns](../models/files-and-storage-columns.md) |
| `BeakUploadClient`, `BeakManagedUploadClient`, `BeakUploadUrlClient` | `packages/beak_core/lib/src/data/beak_upload_client.dart` |
| `BeakDraftUploads` | `packages/beak_frontend/lib/src/form/beak_draft_uploads.dart` |
| `BeakUploadReadPolicy`, the upload routes | `packages/beak_backend/lib/src/auth/beak_policy.dart`, [REST API](../reference/rest-api.md) |

## Continue reading

- [Files and storage columns](../models/files-and-storage-columns.md) declaring `@Image` and `@FileField`.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the driver behind the route.
- [Related records in forms](related-records.md) the owned-row machinery a gallery is built on.
- [Drafts, review and conflicts](drafts-and-review.md) resuming a form that had staged files.
