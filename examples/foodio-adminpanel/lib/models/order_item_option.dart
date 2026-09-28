import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'order_item_option.beak.dart';

/// OrderItemOption configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class OrderItemOption extends BeakSchema {
  /// Selection suggestions share the same snapshot semantics as the order line.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: OrderItemOptionModel.label,
        dependencies: [
          OrderItemOptionModel.option.name,
          OrderItemOptionModel.optionId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemOptionModel.optionId) ==
                    state.original(OrderItemOptionModel.optionId)
            ? state.original(OrderItemOptionModel.label)
            : state.read(OrderItemOptionModel.option.name),
      ),
      BeakValueBehavior.suggested(
        field: OrderItemOptionModel.allergens,
        dependencies: [
          OrderItemOptionModel.option.allergens,
          OrderItemOptionModel.optionId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemOptionModel.optionId) ==
                    state.original(OrderItemOptionModel.optionId)
            ? state.original(OrderItemOptionModel.allergens)
            : state.read(OrderItemOptionModel.option.allergens) ?? '',
      ),
      BeakValueBehavior.suggested(
        field: OrderItemOptionModel.unitPriceCents,
        dependencies: [
          OrderItemOptionModel.option.priceCents,
          OrderItemOptionModel.optionId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemOptionModel.optionId) ==
                    state.original(OrderItemOptionModel.optionId)
            ? state.original(OrderItemOptionModel.unitPriceCents)
            : state.read(OrderItemOptionModel.option.priceCents) ?? 0,
      ),
    ],
  );

  /// Label.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String label;

  /// Order item.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final OrderItem orderItem;

  /// Option.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DishOption option;

  /// Unit price cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int unitPriceCents;

  /// Allergens.
  @Column(defaultValue: '')
  late final String? allergens;
}
