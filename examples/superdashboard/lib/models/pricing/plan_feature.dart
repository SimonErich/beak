import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the plan-features resource.
abstract final class PlanFeatureColumns {
  /// The owning plan.
  static const planId = BeakStringColumn(
    key: 'plan_id',
    label: 'Plan',
    visibleOn: {BeakContext.form},
  );

  /// Feature text.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Feature',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Whether the plan includes this feature (vs. crossed out).
  static const included = BeakBoolColumn(
    key: 'included',
    label: 'Included',
    filterable: true,
  );

  /// Ordering within the plan.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    planId,
    label,
    included,
    sortIndex,
  ];
}

/// Typed relationships of the plan-features resource.
abstract final class PlanFeatureRelations {
  /// The owning plan.
  static const plan = BeakBelongsTo(
    key: 'plan',
    label: 'Plan',
    relatedTable: 'pricing_plans',
    displayColumnKey: 'name',
    foreignKey: 'plan_id',
    searchColumnKeys: ['name'],
  );
}

/// The plan-features resource — one bullet on a pricing plan.
final class PlanFeatureModel extends BeakModel {
  /// Creates the plan-features model.
  const PlanFeatureModel();

  @override
  String get table => 'plan_features';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => PlanFeatureColumns.values;

  @override
  List<BeakRelationship> get relationships => const [PlanFeatureRelations.plan];
}
