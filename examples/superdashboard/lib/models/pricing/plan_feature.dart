import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'pricing_plan.dart';

part 'plan_feature.beak.dart';

/// The plan-features resource — one bullet on a pricing plan.
@Resource()
final class PlanFeature extends BeakSchema {
  /// The owning plan.
  @BelongsTo()
  late final PricingPlan? plan;

  /// Feature text.
  @Display()
  @Column(label: 'Feature', searchable: true, rules: [BeakMaxLength(120)])
  late final String label;

  /// Whether the plan includes this feature (vs. crossed out).
  @Column(filterable: true)
  late final bool? included;

  /// Ordering within the plan.
  @Column(label: 'Order', min: 0, sortable: true)
  late final int? sortIndex;
}
