import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category_attribute.dart';
part 'category.beak.dart';

/// Catalog grouping with reusable attribute definitions.
@Resource()
final class Category extends BeakSchema {
  /// Category title.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Description shown to administrators.
  late final String? description;

  /// Attributes expected for products in this category.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<CategoryAttribute> attributes;
}
