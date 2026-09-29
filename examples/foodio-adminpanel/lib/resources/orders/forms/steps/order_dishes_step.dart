import 'package:beak/panel.dart';

import '../../../../domain/foodio_clock.dart';
import '../../../../models/models.dart';
import '../order_items_table.dart';
import '../order_totals.dart';

/// Menu selection and allergy confirmation step.
BeakWizardStep dishesStep() => BeakWizardStep(
  title: 'Dishes',
  heading: 'Choose dishes',
  introductionBuilder: (state, format) =>
      'From the menu plan ${state.asOrder.profile?.menuPlan?.name ?? 'for this profile'} for ${format.date((state.asOrder.deliveryDate ?? const FoodioClock().today).toDateTime(), pattern: 'EEE d MMM')}.',
  dependencies: [OrderModel.profile.menuPlan.name, OrderModel.deliveryDate],
  spacingInPixels: 24,
  continueLabel: 'Continue to payment',
  description: 'From the menu plan',
  completedDescription: (state, format) {
    final portions = state
        .rows(OrderModel.items)
        .fold<int>(0, (sum, row) => sum + (row.asOrderItem.quantity ?? 0));
    return '$portions dishes · ${format.format(money(orderTotals(state).subtotalCents), BeakValueFormat.currency)}';
  },
  footerHint:
      'Prices include VAT. You can change the order until 10:30 on the delivery day.',
  children: [
    orderItems(catalog: true),
    OrderModel.allergyAcknowledged.inputToggle(
      label: 'Allergen notes reviewed with the customer',
      visibleIf: (state) => state.asOrder.strictAllergy == true,
    ),

    OrderModel.customerNote.inputText(
      label: 'Note for the kitchen',
      visibleIf: (state) => (state.asOrder.customerNote?.isNotEmpty ?? false),
    ),
  ],
);
