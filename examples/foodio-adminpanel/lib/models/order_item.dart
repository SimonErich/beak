import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'order_item.beak.dart';

/// OrderItem configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class OrderItem extends BeakSchema {
  /// Catalog choices fill the form; saved selections retain their price snapshot.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: OrderItemModel.dishId,
        dependencies: [OrderItemModel.variant.dishId],
        resolve: (state) =>
            state.read(OrderItemModel.variant.dishId) ??
            state.read(OrderItemModel.dishId),
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.label,
        dependencies: [
          OrderItemModel.dish.name,
          OrderItemModel.variant.dish.name,
          OrderItemModel.dishId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.dishId) ==
                    state.original(OrderItemModel.dishId)
            ? state.original(OrderItemModel.label)
            : state.read(OrderItemModel.variant.dish.name) ??
                  state.read(OrderItemModel.dish.name) ??
                  state.read(OrderItemModel.label),
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.unitPriceCents,
        dependencies: [
          OrderItemModel.variant.priceCents,
          OrderItemModel.variantId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.variantId) ==
                    state.original(OrderItemModel.variantId)
            ? state.original(OrderItemModel.unitPriceCents)
            : state.read(OrderItemModel.variant.priceCents) ??
                  state.read(OrderItemModel.unitPriceCents) ??
                  0,
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.variantName,
        dependencies: [OrderItemModel.variant.name, OrderItemModel.variantId],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.variantId) ==
                    state.original(OrderItemModel.variantId)
            ? state.original(OrderItemModel.variantName)
            : state.read(OrderItemModel.variant.name) ?? 'Custom',
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.food,
        dependencies: [
          OrderItemModel.dish.food,
          OrderItemModel.variant.dish.food,
          OrderItemModel.dishId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.dishId) ==
                    state.original(OrderItemModel.dishId)
            ? state.original(OrderItemModel.food)
            : state.read(OrderItemModel.variant.dish.food) ??
                  state.read(OrderItemModel.dish.food) ??
                  state.read(OrderItemModel.food) ??
                  true,
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.allergens,
        dependencies: [
          OrderItemModel.dish.allergens,
          OrderItemModel.variant.dish.allergens,
          OrderItemModel.dishId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.dishId) ==
                    state.original(OrderItemModel.dishId)
            ? state.original(OrderItemModel.allergens)
            : state.read(OrderItemModel.variant.dish.allergens) ??
                  state.read(OrderItemModel.dish.allergens) ??
                  state.read(OrderItemModel.allergens) ??
                  '',
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.taxBasisPoints,
        dependencies: [
          OrderItemModel.dish.taxBasisPoints,
          OrderItemModel.variant.dish.taxBasisPoints,
          OrderItemModel.dishId,
        ],
        resolve: (state) =>
            state.initial != null &&
                state.read(OrderItemModel.dishId) ==
                    state.original(OrderItemModel.dishId)
            ? state.original(OrderItemModel.taxBasisPoints)
            : state.read(OrderItemModel.variant.dish.taxBasisPoints) ??
                  state.read(OrderItemModel.dish.taxBasisPoints) ??
                  1000,
      ),
    ],
  );

  /// A variant must belong to the selected dish, in every presentation.
  static List<BeakRecordRule> get validationRules => [
    BeakDistinct(OrderItemModel.fields.options, OrderItemOptionModel.optionId),
    BeakExists(
      OrderItemModel.variantId,
      DishVariantModel.id,
      matching: [
        BeakFieldMatch(
          target: DishVariantModel.dishId,
          source: OrderItemModel.dishId,
        ),
      ],
    ),
  ];

  /// Label.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String label;

  /// Order.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Order order;

  /// Dish.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Dish? dish;

  /// Variant.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final DishVariant? variant;

  /// Quantity.
  @Column(defaultValue: 1, rules: [BeakMin(1)])
  late final int quantity;

  /// Position.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int position;

  /// Unit price cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int unitPriceCents;

  /// Options price cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int optionsPriceCents;

  /// Tax basis points.
  @Column(defaultValue: 1000, rules: [BeakMin(0)])
  late final int taxBasisPoints;

  /// Variant name.
  @Column(defaultValue: '')
  late final String? variantName;

  /// Allergens.
  @Column(defaultValue: '')
  late final String? allergens;

  /// Food.
  @Column(defaultValue: true)
  late final bool food;

  /// Note.
  @Column(defaultValue: '')
  late final String? note;

  /// Gross cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int grossCents;

  /// Discount cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int discountCents;

  /// Net cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int netCents;

  /// Tax cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int taxCents;

  /// Options.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<OrderItemOption> options;
}
