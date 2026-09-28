import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

import '../../models/models.dart';
import '../../theme/gabel_theme.dart';
import 'order_presentations.dart';
import 'order_totals.dart';

/// The collection is reused in the wizard, order details and edit screen.
BeakRelationTable orderItems({
  bool allowEditing = true,
  bool catalog = false,
  bool compact = false,
  bool review = false,
}) => OrderModel.items.tableForm(
  label: 'Dishes',
  showHeading: !compact && !catalog,
  showAddAction: !compact,
  showColumnHeadings: !review && !compact,
  rowPadding: const EdgeInsets.symmetric(vertical: 4),
  rowMinHeight: review ? 20 : 60,
  rowGap: 12,
  reserveActions: compact && !review,
  minRowWidth: review ? 360 : 560,
  identityControlHeight: 28,
  identityControlWidth: 144,
  identityFlex: 4,
  columnWidths: review ? const [72] : const [90, 72],
  columnAlignments: review
      ? const [Alignment.centerRight]
      : const [Alignment.center, Alignment.centerRight],
  advancedPresentation: BeakAdvancedPresentation.inline,
  advancedContentPadding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  ),
  advancedReadVisibleIf: (state) =>
      state.asOrderItem.note?.trim().isNotEmpty ?? false,
  showRowDividers: !review,
  presentation: BeakRelationTablePresentation.rows,
  readOnly: !allowEditing,
  catalog: catalog
      ? BeakRelationCatalog(
          presentation: BeakCatalogPresentation.rows,
          compactToolbar: true,
          controlHeight: 32,
          notice: orderAllergyNotice(plain: true),
          footer:
              'Not on the plan? Switch to All dishes to order anything from the full menu.',
          dependencies: [
            OrderModel.profile.menuPlan.items,
            OrderModel.deliveryDate,
          ],
          groupOrder: (state) {
            final entries =
                (state.read(OrderModel.profile.menuPlan.items) ??
                        <BeakRecord>[])
                    .where(
                      (row) =>
                          row.asMenuPlanItem.date == state.asOrder.deliveryDate,
                    )
                    .toList()
                  ..sort(
                    (a, b) => a.asMenuPlanItem.position.compareTo(
                      b.asMenuPlanItem.position,
                    ),
                  );
            return entries.map((row) => row.asMenuPlanItem.dishId).toList();
          },
          advancedLabel: BeakValueBinding<String>.computed(
            dependencies: [DishVariantModel.dish.fields.options],
            visibleIf: (row) =>
                (row.read(DishVariantModel.dish.fields.options)?.isNotEmpty ??
                false),
            compute: (row) {
              final count =
                  row.read(DishVariantModel.dish.fields.options)?.length ?? 0;
              return '$count ${count == 1 ? 'option' : 'options'}';
            },
          ),
          columnLabels: (
            item: 'Dish',
            variant: 'Variant and price',
            quantity: 'Quantity',
          ),
          selection: OrderItemModel.variant,
          template: variantIdentity(),
          groupBy: DishVariantModel.dishId,
          variantLabel: DishVariantModel.name,
          price: DishVariantModel.priceCents.currency(minorUnits: true),
          quantity: OrderItemModel.quantity,
          options: (state) => DishVariantModel.options(
            filter: BeakAndFilter([
              DishVariantModel.active.eq(true),
              DishVariantModel.dish.active.eq(true),
            ]),
          ),
          searchLabel: 'e.g. schnitzel or risotto',
          searchSources: [
            DishVariantModel.dish.name,
            DishVariantModel.dish.description,
            DishVariantModel.dish.allergens,
          ],
          maxOptions: 200,
          pageSize: 6,
          tabs: [
            BeakCatalogFilter(
              label: 'Menu plan',
              filterBuilder: (state) => BeakOrFilter([
                for (final row
                    in state.read(OrderModel.profile.menuPlan.items) ??
                        <BeakRecord>[])
                  if (row.asMenuPlanItem.date == state.asOrder.deliveryDate)
                    DishVariantModel.dishId.eq(row.asMenuPlanItem.dishId),
              ]),
            ),
            const BeakCatalogFilter(label: 'All dishes'),
            for (final category in ['Drinks', 'Desserts'])
              BeakCatalogFilter(
                label: category,
                filter: DishVariantModel.dish.category.eq(category),
              ),
          ],
          filters: [
            BeakCatalogFilter(
              label: 'Vegetarian',
              filter: DishVariantModel.dish.diet.contains('vegetarian'),
            ),
            BeakCatalogFilter(
              label: 'Vegan',
              filter: DishVariantModel.dish.diet.contains('vegan'),
            ),
            for (final allergen in {'A': 'gluten', 'G': 'milk'}.entries)
              BeakCatalogFilter(
                label: 'Without ${allergen.key} · ${allergen.value}',
                dependencies: [DishVariantModel.dish.allergens],
                matches: (row) =>
                    !(DishVariantModel.dish.allergens.readFrom(row) ?? '')
                        .split(',')
                        .map((code) => code.trim())
                        .contains(allergen.key),
              ),
          ],
        )
      : null,
  rowTemplate: BeakRecordTemplate(
    textGap: review ? 0 : 2,
    identityGap: 12,
    title: review
        ? BeakValueBinding<String>.computed(
            dependencies: [OrderItemModel.quantity, OrderItemModel.label],
            compute: (row) =>
                '${row.read(OrderItemModel.quantity) ?? 0} × ${row.read(OrderItemModel.label) ?? 'Dish'}',
          )
        : BeakValueBinding.field(
            OrderItemModel.label,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: null,
          ),
    inlineBadges: false,
    inlineSubtitle: !review,
    subtitle: [
      if (!review) ...[
        BeakValueBinding<String>.computed(
          dependencies: [OrderItemModel.fields.options],
          visibleIf: (row) =>
              (row.read(OrderItemModel.fields.options)?.isNotEmpty ?? false),
          compute: (row) => (row.read(OrderItemModel.fields.options) ?? [])
              .map((option) => option.asOrderItemOption.label)
              .whereType<String>()
              .map(
                (label) =>
                    '+ ${label.replaceFirst(RegExp(r'^Extra ', caseSensitive: false), 'extra ')}',
              )
              .join(', '),
          color: BeakColor.muted,
          textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
        ),
        _itemAllergens(),
        BeakValueBinding<String>.computed(
          dependencies: [
            OrderItemModel.allergens,
            OrderItemModel.taxBasisPoints,
          ],
          visibleIf: (row) =>
              (row.read(OrderItemModel.allergens) ?? '').isEmpty,
          compute: (row) =>
              'No allergens · ${(row.read(OrderItemModel.taxBasisPoints) ?? 0) ~/ 100}% VAT',
          color: BeakColor.muted,
          textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
        ),
        BeakValueBinding<String>.computed(
          dependencies: const [],
          visibleIf: (row) => row is BeakDraftRecord && row.id == null,
          compute: (_) => 'Added now',
          color: BeakColor.muted,
          textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
        ),
      ],
    ],
    icon: review
        ? null
        : BeakValueBinding<IconData>.computed(
            dependencies: [
              OrderItemModel.dish.category,
              OrderItemModel.dish.diet,
            ],
            compute: (row) => dishIcon(
              row.read(OrderItemModel.dish.category),
              row.read(OrderItemModel.dish.diet),
            ),
          ),
    avatarPalette: identityPalette,
    avatarTone: dishToneBinding(
      OrderItemModel.dish.category,
      OrderItemModel.dish.diet,
    ),
    trailing: [
      if (review)
        BeakValueBinding.field(
          OrderItemModel.variantName,
          color: BeakColor.muted,
          textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
        ),
      if (review) allergenBadges(OrderItemModel.allergens),
    ],
  ),
  minRows: 1,
  allowAdding: allowEditing,
  allowEdit: allowEditing,
  allowRemove: allowEditing,
  removeBehavior: BeakRemoveBehavior.deleteOwned,
  identityChildren: [
    if (!review)
      OrderItemModel.variant.inputCombobox(
        label: 'Size',
        template: BeakRecordTemplate(
          title: BeakValueBinding<String>.computed(
            dependencies: [DishVariantModel.name, DishVariantModel.weightGrams],
            compute: (row) => _variantLabel(
              row.read(DishVariantModel.name),
              row.read(DishVariantModel.weightGrams),
            ),
            textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
          ),
        ),
        validate: const [BeakRequired()],
        options: (state) => DishVariantModel.options(
          filter: DishVariantModel.dishId.eq(state.asOrderItem.dishId ?? ''),
        ),
      ),
  ],
  children: [
    if (!review)
      OrderItemModel.quantity.inputQuantity(label: 'Qty', controlWidth: 90),
    BeakCalculated(
      valueStyle: gabelNumericMediumStyle,
      label: 'Total',
      format: BeakValueFormat.currency,
      textAlign: TextAlign.end,
      subtitle: review
          ? null
          : (state, format) =>
                '${format.currency((state.asOrderItem.unitPriceCents ?? 0) / 100)} each',
      value: (state) => money(
        (state.asOrderItem.quantity ?? 0) *
            ((state.asOrderItem.unitPriceCents ?? 0) +
                state
                    .rows(OrderItemModel.fields.options)
                    .fold<int>(
                      0,
                      (sum, option) =>
                          sum + (option.asOrderItemOption.unitPriceCents ?? 0),
                    )),
      ),
    ),
  ],
  advancedForm: review
      ? null
      : BeakFormLayout(
          spacing: catalog ? 8 : 16,
          children: [
            if (catalog)
              BeakCalculated(
                value: (state) =>
                    'Options for ${state.asOrderItem.quantity == 1 ? 'this portion' : 'all ${state.asOrderItem.quantity} portions'}',
                valueStyle: const TextStyle(fontSize: 12, height: 4 / 3),
              ),
            OrderItemModel.dish.inputCombobox(
              label: 'Dish',
              validate: const [BeakRequired()],
              visibleIf: (state) => state.asOrderItem.variantId == null,
            ),
            OrderItemModel.fields.options.tableForm(
              label: 'Extras',
              showHeading: !catalog,
              presentation: BeakRelationTablePresentation.rows,
              showColumnHeadings: false,
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              children: const [],
              catalog: BeakRelationCatalog(
                presentation: BeakCatalogPresentation.checkboxes,
                selection: OrderItemOptionModel.option,
                maxOptions: 100,
                template: BeakRecordTemplate(
                  title: BeakValueBinding.field(DishOptionModel.name),
                  inlineBadges: true,
                  badges: [
                    BeakValueBinding<int>.field(
                      DishOptionModel.priceCents,
                      display: (price, format) =>
                          "+${format.format(money(price ?? 0), BeakValueFormat.currency)}",
                      textStyle: gabelNumericMediumStyle,
                    ),
                    BeakValueBinding<String>.computed(
                      dependencies: [
                        DishOptionModel.allergens,
                        DishOptionModel.dish.allergens,
                      ],
                      compute: (row) =>
                          "contains ${_additionalOptionAllergens(row).map(allergenLabel).join(', ')}",
                      visibleIf: (row) =>
                          _additionalOptionAllergens(row).isNotEmpty,
                      textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                      color: BeakColor.muted,
                    ),
                    BeakValueBinding<List<String>>.computed(
                      dependencies: [
                        DishOptionModel.allergens,
                        DishOptionModel.dish.allergens,
                      ],
                      compute: _additionalOptionAllergens,
                      badge: true,
                      badgeToken: true,
                      itemTooltip: (code, _) => allergenLabel(code.toString()),
                    ),
                  ],
                ),
                options: (state) => DishOptionModel.options(
                  filter: BeakAndFilter([
                    DishOptionModel.dishId.eq(state.asOrderItem.dishId ?? ''),
                    DishOptionModel.active.eq(true),
                  ]),
                ),
              ),
              rowTemplate: BeakRecordTemplate(
                title: BeakValueBinding.field(OrderItemOptionModel.label),
                inlineBadges: true,
                badges: [
                  BeakValueBinding.field(
                    OrderItemOptionModel.unitPriceCents.currency(
                      minorUnits: true,
                    ),
                  ),
                ],
              ),
            ),
            if (!catalog)
              BeakCard(
                title: 'Preparation note',
                presentation: BeakCardPresentation.plain,
                collapsible: true,
                initiallyExpanded: false,
                children: [OrderItemModel.note.inputText(label: 'Note')],
              ),
          ],
        ),
  summaryLabel: 'Subtotal',
  summaryFormat: BeakValueFormat.currency,
  summary: compact || catalog
      ? null
      : (rows) => money(
          rows.fold<int>(
            0,
            (sum, state) =>
                sum +
                (state.asOrderItem.quantity ?? 0) *
                    ((state.asOrderItem.unitPriceCents ?? 0) +
                        state
                            .rows(OrderItemModel.fields.options)
                            .fold<int>(
                              0,
                              (sum, option) =>
                                  sum +
                                  (option.asOrderItemOption.unitPriceCents ??
                                      0),
                            )),
          ),
        ),
);

List<String> _additionalOptionAllergens(BeakDraftReader row) {
  Set<String> codes(String? value) => (value ?? '')
      .split(',')
      .map((code) => code.trim())
      .where((code) => code.isNotEmpty)
      .toSet();
  return codes(
    row.read(DishOptionModel.allergens),
  ).difference(codes(row.read(DishOptionModel.dish.allergens))).toList();
}

String _variantLabel(String? name, int? weight) =>
    '${name ?? 'Standard'}${weight == null || weight == 0 || !{'Regular', 'Large', 'Kids'}.contains(name) ? '' : ' ($weight g)'}';

BeakValueBinding<List<String>> _itemAllergens() =>
    BeakValueBinding<List<String>>.computed(
      dependencies: [OrderItemModel.allergens],
      compute: (row) => (row.read(OrderItemModel.allergens) ?? '')
          .split(',')
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toList(),
      badge: true,
      badgeToken: true,
      itemTone: (code, row) {
        final parent = row is BeakDraftRecord ? row.parent : null;
        final alert = parent?.read(OrderModel.customer.allergens) ?? '';
        return alert.split(',').map((code) => code.trim()).contains(code)
            ? BeakColor.warning
            : BeakColor.muted;
      },
      itemTooltip: (code, _) => switch (code) {
        'A' => 'A · gluten',
        'C' => 'C · eggs',
        'G' => 'G · milk',
        'H' => 'H · tree nuts',
        'L' => 'L · celery',
        'M' => 'M · mustard',
        _ => '$code · allergen',
      },
    );
