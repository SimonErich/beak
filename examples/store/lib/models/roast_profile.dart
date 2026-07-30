import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'roast_profile.beak.dart';

/// How dark a coffee is roasted.
enum RoastLevel {
  /// Bright and acidic.
  light,

  /// Balanced.
  medium,

  /// Bold and bitter.
  dark,
}

/// The roasting detail of a coffee product — at most one per product.
///
/// The one-to-one case: the foreign key lives here, and [Product.roastProfile]
/// declares the parent side with `@HasOne`.
@Resource()
final class RoastProfile extends BeakSchema {
  /// What the profile is called.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(80)])
  late final String name;

  /// How dark the roast is.
  @Column(filterable: true)
  late final RoastLevel level;

  /// Roasting time in minutes.
  @Column(suffix: ' min', min: 1, max: 30)
  late final int durationInMinutes;

  /// The product this profile roasts.
  @BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
  late final Product product;
}
