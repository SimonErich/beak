# Uploads and galleries

> Stage uploads and ordered image collections in ordinary declarative form drafts.

Image and file schema fields automatically use the platform picker. Declare their
storage path, accepted MIME types, size limit and transforms on `@Image` or `@FileField`.
The configured server owns storage; a form only needs the generated field's
`.input()` placement. A resource may override `filePicker` or `uploader` for a
camera, asset library or alternate transport.

For multiple images, use an owned relationship and ordinary child metadata:

```dart
ProductModel.images.galleryForm(
  image: ProductImageModel.image,
  caption: ProductImageModel.caption,
  position: ProductImageModel.position,
  label: 'Product gallery',
)
```

The gallery presents image previews, editable descriptions, optional extra
`metadata` fields, accessible move controls and removal. The first position is the
cover. Reordering changes the local draft; image records and positions save with
the parent graph. Shared, unowned relationships are rejected to prevent deletion
of media records belonging to another aggregate.

## Upload lifecycle

Selecting a file validates its size and MIME type and stages bytes locally. No
remote upload happens until the complete form passes validation and Save begins.
Replaced or removed selections are excluded. Image dimensions and transforms are
checked by the server during upload.

The graph submitted to storage contains final keys, never local preview keys. A
failed graph save reuses uploaded files on retry. A confirmed save adopts them.
Abandoning a draft discards only files uploaded by that draft whose writes are
known not to have committed. Existing keys are never treated as disposable.

An unknown save response retains its uploads until receipt recovery proves the
outcome. Closing during submission waits for its result before cleanup. Hosts can
observe `session.uploadCleanup` and retry `session.uploader?.dispose()` after a
cleanup failure. Native HTTP transport removes all generated renditions.

Storage and the database are separate systems. A process crash or interrupted
upload response can leave an orphan whose key the client never received.
Production storage maintenance should expire old unreferenced uploads after
checking record references; client-side cancellation cannot guarantee crash-proof
collection. Deleting an existing media row also leaves physical storage deletion
to such a reference-aware policy, since other records may still use that key.

## Stored previews and custom transports

Stored keys resolve through the authorized `GET /api/{table}/{column}/upload?key=`
endpoint, so public and signed storage URLs both work after reopening a record.
URL resolution does not assume a storage origin or confuse a key with an HTTP URL.

The endpoint checks resource read permission. With `BeakRowPolicy`, it also checks
that a visible record references the key in this exact upload column; hidden and
unreferenced keys both return `404`. Implement `BeakUploadReadPolicy.canViewUpload`
for additional key-specific restrictions. Newly staged previews use the upload
response directly, so they do not need an ownership lookup before the row exists.

The local disk driver's file URLs and public buckets remain public. Authorizing
URL lookup does not make an already public URL private. Use a private storage
driver that issues signed, expiring URLs for confidential media.

Custom transports can implement `BeakManagedUploadClient` to discard new files
and `BeakUploadUrlClient` to resolve stored previews. Upload-only transports remain
usable, with cleanup managed by their host. The standalone `BeakUploadField`
uses its supplied transport directly; `BeakFormSession` supplies automatic staging.

See the product gallery schema and layout in
`examples/clean_beak_config/lib/resources/products/`.

## Continue reading

- [Semantic fields](../models/semantic-fields.md) for typed inputs and storage codecs.
- [Multi-step forms](multi-step-forms.md) for saving complete related drafts together.
