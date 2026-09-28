---
title: Files and storage columns
description: Declare managed upload fields and ordered media collections.
---

# Files and storage columns

`@Image` and `@FileField` describe managed references, MIME restrictions, size limits and storage paths. A single reference uses the generated upload input. Multiple images use an owned related model and `.galleryForm()` so order, captions and identity remain explicit.

New local files belong to the draft until commitment. Cancelling a draft cleans up staged work according to the source's upload contract. Durable drafts exclude local bytes, so unfinished files need reselection after restoration. Server policies gate upload operations and URL resolution; storage delivery controls whether an issued URL itself is public.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_image.dart"
```

## Continue reading

- [Media galleries](../panel/media-galleries.md)
- [Upload wiring](../backend/uploads-and-storage-wiring.md)
