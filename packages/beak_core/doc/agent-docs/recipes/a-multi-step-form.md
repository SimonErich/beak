# A multi-step form

> Project reusable sections into a validated wizard.

Configure a `BeakWizardScreen` from `BeakWizardStep` nodes, or project shared `BeakFormSections` into steps. Beak validates each step, retains values while navigating and saves the complete draft graph on Finish.

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
import 'package:beak/panel.dart';
import '../../../shop_drafts.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_discount.dart';

/// A staged order draft presented in four validated steps.
final class OrderFormWizardScreen extends BeakWizardScreen {
  /// Fetching, relationship state, validation and saving are automatic.
  OrderFormWizardScreen()
    : super(
        steps: orderSteps(),
        drafts: shopDrafts('order'),
        reviewBeforeSave: true,
      );
}

/// Shared structure for both the wizard and tabbed order detail view.
List<BeakWizardStep> orderSteps() => orderSections().steps;

/// Named sections projected into a wizard, tabs or an ordinary form.
BeakFormSections orderSections() => BeakFormSections(
  sections: [
    BeakSection(
      title: 'Select a customer',
      description: 'Identify the order and its customer.',
      children: [
        BeakColumns(
          children: [
            BeakCard(
              title: 'Order',
              children: [
                OrderModel.reference.inputText(label: 'Order reference'),
                OrderModel.status.input(),
              ],
            ),
            BeakCard(
              title: 'Customer',
              children: [OrderModel.customer.inputCombobox()],
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Profile and delivery',
      description: 'Choose an address belonging to the selected customer.',
      children: [
        BeakColumns(
          children: [
            BeakCard(
              title: 'Delivery details',
              children: [
                OrderModel.profile.inputCombobox(),
                OrderModel.deliveryDate.inputDateTime(
                  label: 'When should it arrive?',
                  description: 'Choose a practical delivery date and time.',
                  validators: [
                    (value, state) =>
                        state.draft.id == null &&
                            value != null &&
                            !value.isAfter(DateTime.now())
                        ? 'Choose a future delivery date.'
                        : null,
                  ],
                ),
              ],
            ),
            BeakCard(
              title: 'Fulfillment notes',
              children: [OrderModel.notes.inputText(label: 'Internal notes')],
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Order items',
      description: 'Add catalog items, variants or custom services.',
      children: [
        OrderModel.items.tableForm(
          label: 'Products and services',
          minRows: 1,
          removeBehavior: BeakRemoveBehavior.deleteOwned,
          children: [
            OrderItemModel.product.inputCombobox(),
            OrderItemModel.variant.inputCombobox(),
            OrderItemModel.quantity.inputNumber(),
            const BeakCalculated(
              label: 'Net line total',
              value: lineTotal,
              format: BeakValueFormat.currency,
            ),
          ],
          advancedForm: BeakFormLayout(
            children: [
              BeakColumns(
                children: [
                  BeakCard(
                    title: 'Description',
                    children: [
                      OrderItemModel.label.inputText(label: 'Line description'),
                      OrderItemModel.taxRate.inputCombobox(label: 'Tax rate'),
                    ],
                  ),
                  BeakCard(
                    title: 'Price adjustments',
                    children: [
                      OrderItemModel.overwritePrice.inputCurrency(
                        label: 'Negotiated unit price',
                      ),
                      OrderItemModel.discount.inputCurrency(
                        label: 'Line discount',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          summary: (rows) =>
              rows.fold<double>(0, (total, row) => total + lineTotal(row)),
          summaryFormat: BeakValueFormat.currency,
          summaryLabel: 'Net items total',
        ),
      ],
    ),
    BeakSection(
      title: 'Adjustments & review',
      description: 'Review the order before saving.',
      children: [
        BeakCard(
          title: 'Order adjustments',
          children: [
            OrderModel.discounts.tableForm(
              label: 'Discount adjustments',
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              children: [
                OrderDiscountModel.reason.inputText(),
                OrderDiscountModel.amount.inputCurrency(),
              ],
              summary: (rows) => rows.fold<double>(
                0,
                (sum, row) => sum + (row.asOrderDiscount.amount ?? 0),
              ),
              summaryFormat: BeakValueFormat.currency,
              summaryLabel: 'Total adjustments',
            ),
          ],
        ),
        BeakCard(
          title: 'Order summary',
          children: [
            BeakColumns(
              children: [
                BeakCalculated(
                  label: 'Customer',
                  value: (state) => state.asOrder.customer?.email,
                ),
                BeakCalculated(
                  label: 'Delivery',
                  value: (state) => state.asOrder.deliveryDate,
                  format: BeakValueFormat.dateTime,
                ),
                BeakCalculated(
                  label: 'Order net total',
                  format: BeakValueFormat.currency,
                  value: (state) =>
                      state
                          .rows(OrderModel.items)
                          .fold<double>(0, (sum, row) => sum + lineTotal(row)) -
                      state
                          .rows(OrderModel.discounts)
                          .fold<double>(
                            0,
                            (sum, row) =>
                                sum + (row.asOrderDiscount.amount ?? 0),
                          ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Net line calculation; invoice tax is calculated separately when invoicing.
double lineTotal(BeakFormReader state) {
  final item = state.asOrderItem;
  return ((item.quantity ?? 0) *
                  (item.overwritePrice ??
                      item.variant?.price ??
                      item.product?.price ??
                      0) *
                  100 -
              (item.discount ?? 0) * 100)
          .round() /
      100;
}
```

## Continue reading

- [Related guide](../forms/multi-step-forms.md)
- [All recipes](index.md)
