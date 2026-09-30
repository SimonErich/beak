import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'product_image.beak.dart';

/// One ordered catalog picture with accessible description.
@Resource()
final class ProductImage extends BeakSchema {
  // --8<-- [start:productImageColumn]
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
  // --8<-- [end:productImageColumn]

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
