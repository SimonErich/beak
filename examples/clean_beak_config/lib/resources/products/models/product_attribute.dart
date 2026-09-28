import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';
import '../../categories/models/category_attribute.dart';
part 'product_attribute.beak.dart';

/// A named product value, optionally linked to a category definition.
@Resource()
final class ProductAttribute extends BeakSchema {
  /// Display label, retained if a definition is removed later.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Attribute value as entered for the product.
  @Column(searchable: true)
  late final String value;

  /// Optional category definition used to interpret this value.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.setNull)
  late final CategoryAttribute? definition;

  /// Product that owns the value.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Product product;
}
