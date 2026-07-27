import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'product_image.beak.dart';

/// The product-images resource — one image in a product's gallery.
@Resource()
final class ProductImage extends BeakSchema {
  /// The image URL.
  @Image(storagePath: 'product-images')
  @Column(label: 'Image')
  late final BeakImageRef url;

  /// Alt text / caption.
  @Display()
  @Column(label: 'Caption', searchable: true, rules: [BeakMaxLength(160)])
  late final String? alt;

  /// Ordering within the gallery.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;

  /// Whether this is the primary (hero) image.
  @Column(label: 'Primary')
  late final bool? isPrimary;

  /// The owning product.
  @BelongsTo()
  late final Product? product;
}
