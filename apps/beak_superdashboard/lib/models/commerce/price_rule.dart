import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// How a [PriceRuleModel] adjusts a product's price.
enum PriceRuleKind {
  /// A percentage off the base price.
  percentage,

  /// A fixed amount off the base price.
  fixed,

  /// An absolute override price.
  override,
}

/// Typed columns of the price-rules resource — a conditional pricing
/// adjustment on a product (bulk discount, sale window, member price).
abstract final class PriceRuleColumns {
  /// Rule name, e.g. "Bulk 10+".
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Rule',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// How the adjustment applies.
  static const kind = BeakEnumColumn<PriceRuleKind>(
    key: 'kind',
    label: 'Kind',
    values: PriceRuleKind.values,
    defaultValue: PriceRuleKind.percentage,
    filterable: true,
    badgeColors: {
      PriceRuleKind.percentage: BeakColor.info,
      PriceRuleKind.fixed: BeakColor.secondary,
      PriceRuleKind.override: BeakColor.warning,
    },
  );

  /// The adjustment value (percent, or dollars).
  static const value = BeakDecimalColumn(
    key: 'value',
    label: 'Value',
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Minimum quantity for the rule to apply.
  static const minQuantity = BeakIntColumn(
    key: 'min_quantity',
    label: 'Min qty',
    min: 1,
  );

  /// When the rule starts applying.
  static const startsAt = BeakDateTimeColumn(
    key: 'starts_at',
    label: 'Starts',
    sortable: true,
  );

  /// When the rule stops applying.
  static const endsAt = BeakDateTimeColumn(key: 'ends_at', label: 'Ends');

  /// Whether the rule is currently active.
  static const active = BeakBoolColumn(key: 'active', label: 'Active');

  /// The owning product.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    kind,
    value,
    minQuantity,
    startsAt,
    endsAt,
    active,
    productId,
  ];
}

/// Typed relationships of the price-rules resource.
abstract final class PriceRuleRelations {
  /// The owning product.
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'product_id',
    searchColumnKeys: ['name'],
  );
}

/// The price-rules resource — a conditional pricing adjustment on a product.
final class PriceRuleModel extends BeakModel {
  /// Creates the price-rules model.
  const PriceRuleModel();

  @override
  String get table => 'price_rules';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => PriceRuleColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    PriceRuleRelations.product,
  ];
}
