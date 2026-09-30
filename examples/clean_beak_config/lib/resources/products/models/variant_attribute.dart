import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product_variant.dart';
part 'variant_attribute.beak.dart';

/// One characteristic of a product variant.
@Resource()
final class VariantAttribute extends BeakSchema {
  /// Characteristic name, such as grind or package size.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Choice value.
  @Column(searchable: true)
  late final String value;

  /// Owning variant.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final ProductVariant variant;
}
