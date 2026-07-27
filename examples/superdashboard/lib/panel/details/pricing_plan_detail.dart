import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The pricing-plan show page: a headline strip of the plan identity and
/// pricing, a two-column body splitting the price grid from the card
/// presentation, and a card listing the plan's features.
const BeakBlock pricingPlanDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Pricing Plan',
      child: BeakFieldGroupBlock([
        PricingPlanColumns.name,
        PricingPlanColumns.currency,
        PricingPlanColumns.monthlyPrice,
        PricingPlanColumns.featured,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Pricing',
          child: BeakFieldGroupBlock([
            PricingPlanColumns.monthlyPrice,
            PricingPlanColumns.yearlyPrice,
            PricingPlanColumns.currency,
          ], columnCount: 3),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Presentation',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(PricingPlanColumns.tagline),
              BeakFieldGroupBlock([
                PricingPlanColumns.badge,
                PricingPlanColumns.featured,
                PricingPlanColumns.sortIndex,
              ]),
            ],
          ),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Features',
      child: BeakRelationBlock(PricingPlanRelations.features),
    ),
  ],
);
