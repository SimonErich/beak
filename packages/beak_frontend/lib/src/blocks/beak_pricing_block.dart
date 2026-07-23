part of 'beak_block.dart';

/// A data-bound pricing table: a plans model rendered on `OiPricingTable`,
/// with each plan's per-plan feature list drawn from a relation.
///
/// [nameField] and [priceField] head each plan card, [featuredField] flags
/// the recommended plan, and [descriptionField]/[ctaField] fill it in.
/// [yearlyPriceField] feeds the annual price (`OiPricingTable` models the
/// billing period itself, so there is no per-plan "period" field). When
/// [featuresRelation] and [featureLabelField] are bound, each plan's
/// eager-loaded feature records become its feature bullet list.
///
/// ```dart
/// BeakPricingBlock(
///   model: const PlanModel(),
///   nameField: PlanColumns.name,
///   priceField: PlanColumns.monthlyPrice,
///   featuredField: PlanColumns.recommended,
///   featuresRelation: PlanRelations.features,
///   featureLabelField: FeatureColumns.label,
/// );
/// ```
final class BeakPricingBlock extends BeakBlock {
  /// Creates a pricing block over the plans [model].
  const BeakPricingBlock({
    required this.model,
    required this.nameField,
    required this.priceField,
    this.yearlyPriceField,
    this.featuredField,
    this.descriptionField,
    this.ctaField,
    this.featuresRelation,
    this.featureLabelField,
    this.sortField,
    this.label = 'Pricing',
    this.currencySymbol = r'$',
    super.span,
  });

  /// The plans model whose records become pricing cards.
  final BeakModel model;

  /// Column supplying each plan's name.
  final BeakColumn nameField;

  /// Column supplying each plan's monthly price.
  final BeakColumn priceField;

  /// Column supplying each plan's annual price, when bound.
  final BeakColumn? yearlyPriceField;

  /// Boolean column flagging the recommended plan, when bound.
  final BeakColumn? featuredField;

  /// Column supplying each plan's description, when bound.
  final BeakColumn? descriptionField;

  /// Column supplying each plan's call-to-action label, when bound.
  final BeakColumn? ctaField;

  /// The relation whose eager-loaded records list each plan's features.
  final BeakRelationship? featuresRelation;

  /// Column read for each feature record's bullet label.
  final BeakColumn? featureLabelField;

  /// Column ordering the plans left-to-right, when bound.
  final BeakColumn? sortField;

  /// Accessibility label for the table.
  final String label;

  /// Currency prefix shown on prices.
  final String currencySymbol;
}
