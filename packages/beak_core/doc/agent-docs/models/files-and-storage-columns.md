# Files and storage columns

> Declare managed upload fields and ordered media collections.

`@Image` and `@FileField` describe managed references, MIME restrictions, size limits and storage paths. A single reference uses the generated upload input. Multiple images use an owned related model and `.galleryForm()` so order, captions and identity remain explicit.

New local files belong to the draft until commitment. Cancelling a draft cleans up staged work according to the source's upload contract. Durable drafts exclude local bytes, so unfinished files need reselection after restoration. Server policies gate upload operations and URL resolution; storage delivery controls whether an issued URL itself is public.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'product_image.beak.dart';

/// One ordered catalog picture with accessible description.
@Resource()
final class ProductImage extends BeakSchema {
  /// The uploaded original and automatic thumbnail.
  @Image(
    storagePath: 'product-images',
    maxSizeInBytes: 10485760,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg, BeakFileType.webp],
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions.square(480),
        name: 'thumbnail',
      ),
    ],
  )
  late final BeakImageRef image;

  /// Alternate text describing the product in the image.
  @Display()
  @Column(
    label: 'Image description',
    rules: [BeakMaxLength(240)],
    searchable: true,
  )
  late final String caption;

  /// Gallery position, zero being the product cover.
  @Column(rules: [BeakMin(0)], sortable: true)
  late final int position;

  /// Product owning this picture.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Product product;
}
```

## Continue reading

- [Media galleries](../forms/uploads-and-galleries.md)
- [Upload wiring](../backend/uploads-and-storage-wiring.md)
