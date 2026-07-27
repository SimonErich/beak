import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'plan_feature.dart';

part 'pricing_plan.beak.dart';

/// The pricing-plans resource — a subscription tier.
@Resource()
final class PricingPlan extends BeakSchema {
  /// Plan name, e.g. `Professional`.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(60)])
  late final String name;

  /// Short tagline.
  @Column(rules: [BeakMaxLength(120)])
  late final String? tagline;

  /// Monthly price.
  @Column(label: 'Monthly', prefix: r'$', sortable: true)
  late final double? monthlyPrice;

  /// Yearly price.
  @Column(label: 'Yearly', prefix: r'$', sortable: true)
  late final double? yearlyPrice;

  /// Currency code.
  @Column(
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(3)],
  )
  late final String? currency;

  /// Whether this is the highlighted (recommended) plan.
  @Column(filterable: true)
  late final bool? featured;

  /// Optional badge text, e.g. `Popular`.
  @Column(
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(20)],
  )
  late final String? badge;

  /// Card ordering.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;

  /// The features listed on this plan.
  @HasMany(foreignKey: 'plan_id')
  late final List<PlanFeature> features;
}
