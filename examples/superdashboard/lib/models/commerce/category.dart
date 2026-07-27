import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'category.beak.dart';

/// The categories resource — the product catalog's top-level grouping.
@Resource()
final class Category extends BeakSchema {
  /// Category name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Products filed under this category.
  @HasMany()
  late final List<Product> products;
}
