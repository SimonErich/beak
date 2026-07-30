import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'tag.beak.dart';

/// The tags resource — free-form product labels.
@Resource()
final class Tag extends BeakSchema {
  /// Tag name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(60)])
  late final String name;

  /// Products carrying this tag, via the `product_tag` pivot.
  @BelongsToMany()
  late final List<Product> products;
}
