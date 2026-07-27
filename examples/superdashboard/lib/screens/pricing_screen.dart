import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';
import 'package:obers_ui/obers_ui.dart';

/// The pricing page — plan cards with feature lists and a highlighted
/// featured plan, all from the seeded `pricing_plans` and `plan_features`.
BeakScreen buildPricingScreen() => const BeakScreen(
  path: '/pricing',
  title: 'Pricing',
  icon: BeakIconToken(OiIcons.dollarSign),
  section: 'Pages',
  body: BeakPricingBlock(
    model: PricingPlanModel(),
    nameField: PricingPlanColumns.name,
    priceField: PricingPlanColumns.monthlyPrice,
    yearlyPriceField: PricingPlanColumns.yearlyPrice,
    featuredField: PricingPlanColumns.featured,
    descriptionField: PricingPlanColumns.tagline,
    featuresRelation: PricingPlanRelations.features,
    featureLabelField: PlanFeatureColumns.label,
  ),
);
