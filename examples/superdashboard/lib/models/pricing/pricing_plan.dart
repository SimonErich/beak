import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the pricing-plans resource.
abstract final class PricingPlanColumns {
  /// Plan name, e.g. `Professional`.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Short tagline.
  static const tagline = BeakStringColumn(
    key: 'tagline',
    label: 'Tagline',
    rules: [BeakMaxLength(120)],
  );

  /// Monthly price.
  static const monthlyPrice = BeakDecimalColumn(
    key: 'monthly_price',
    label: 'Monthly',
    prefix: r'$',
    sortable: true,
  );

  /// Yearly price.
  static const yearlyPrice = BeakDecimalColumn(
    key: 'yearly_price',
    label: 'Yearly',
    prefix: r'$',
    sortable: true,
  );

  /// Currency code.
  static const currency = BeakStringColumn(
    key: 'currency',
    label: 'Currency',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(3)],
  );

  /// Whether this is the highlighted (recommended) plan.
  static const featured = BeakBoolColumn(
    key: 'featured',
    label: 'Featured',
    filterable: true,
  );

  /// Optional badge text, e.g. `Popular`.
  static const badge = BeakStringColumn(
    key: 'badge',
    label: 'Badge',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMaxLength(20)],
  );

  /// Card ordering.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    tagline,
    monthlyPrice,
    yearlyPrice,
    currency,
    featured,
    badge,
    sortIndex,
  ];
}

/// Typed relationships of the pricing-plans resource.
abstract final class PricingPlanRelations {
  /// The features listed on this plan.
  static const features = BeakHasMany(
    key: 'features',
    label: 'Features',
    relatedTable: 'plan_features',
    displayColumnKey: 'label',
    foreignKey: 'plan_id',
  );
}

/// The pricing-plans resource — a subscription tier.
final class PricingPlanModel extends BeakModel {
  /// Creates the pricing-plans model.
  const PricingPlanModel();

  @override
  String get table => 'pricing_plans';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => PricingPlanColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    PricingPlanRelations.features,
  ];
}
