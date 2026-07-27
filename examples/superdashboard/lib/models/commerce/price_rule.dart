import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'price_rule.beak.dart';

/// How a [PriceRuleModel] adjusts a product's price.
enum PriceRuleKind {
  /// A percentage off the base price.
  percentage,

  /// A fixed amount off the base price.
  fixed,

  /// An absolute override price.
  override,
}

/// The price-rules resource — a conditional pricing adjustment on a product.
@Resource()
final class PriceRule extends BeakSchema {
  /// Rule name, e.g. "Bulk 10+".
  @Display()
  @Column(label: 'Rule', searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// How the adjustment applies.
  @Column(defaultValue: PriceRuleKind.percentage, filterable: true)
  @Badges({
    PriceRuleKind.percentage: BeakColor.info,
    PriceRuleKind.fixed: BeakColor.secondary,
    PriceRuleKind.override: BeakColor.warning,
  })
  late final PriceRuleKind? kind;

  /// The adjustment value (percent, or dollars).
  @Column(rules: [BeakMin(0)])
  late final double value;

  /// Minimum quantity for the rule to apply.
  @Column(label: 'Min qty', min: 1)
  late final int? minQuantity;

  /// When the rule starts applying.
  @Column(label: 'Starts', sortable: true)
  late final DateTime? startsAt;

  /// When the rule stops applying.
  @Column(label: 'Ends')
  late final DateTime? endsAt;

  /// Whether the rule is currently active.
  late final bool? active;

  /// The owning product.
  @BelongsTo()
  late final Product? product;
}
