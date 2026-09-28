import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'menu_plan_item.beak.dart';

/// MenuPlanItem configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class MenuPlanItem extends BeakSchema {
  /// Menu rows inherit their display label from the selected dish.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: MenuPlanItemModel.name,
        dependencies: [MenuPlanItemModel.dish.name],
        resolve: (state) => state.read(MenuPlanItemModel.dish.name) ?? '',
      ),
    ],
  );

  /// Name.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Menu plan.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final MenuPlan menuPlan;

  /// Dish.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Dish dish;

  /// Date.
  @Column(sortable: true, filterable: true)
  late final BeakDate date;

  /// Position.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int position;
}
