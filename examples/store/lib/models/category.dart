import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A shelf of the catalog.
///
/// The `products` side of the relationship is not declared here: `@BelongsTo`
/// on [Product.category] generates it, so the pair cannot drift apart.
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
