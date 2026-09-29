# Multi-step forms

> Present one managed draft in validated steps.

A `BeakWizardScreen` supplies steps to the same form session used by ordinary screens. Moving between steps retains values and related edits. Going forward validates the current step; finishing validates the submitted graph.

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

For rail navigation, `BeakWizardStep.heading` and `introduction` declare the main step header separately from the short navigation `title` and `description`. The header stays above the scrolling inputs, alongside the pinned actions and independent summary. Both values fall back to the navigation text when omitted; no wrapper section or custom widget is needed.

Keep steps aligned with user decisions: choose the customer, arrange delivery, edit items, review the result. Use cards and columns inside a step for grouping. A selected customer can constrain a later relationship through a shared eligibility rule.

Use `BeakFormSections` when the same sections should become an edit screen with tabs. Presentation does not define an alternative save path: both screens execute the same model constraints and actions.

All relationship changes remain local until submission. Cancelling an inner editor restores that editor's checkpoint; abandoning a wizard follows the form's draft policy.

## Continue reading

- [Forms](form-screens.md)
- [Declarative resources](../concepts/declarative-resources.md)

## Dynamic guidance

Use `navigationDescription` for a short explanation beneath the rail. Step
`introductionBuilder` and `footerHintBuilder` can name a selected customer,
delivery date, or approval recipient from the same draft. List related fields
in the step's `dependencies`; simple scalar values already belong to the form.
The callbacks receive the global formatting policy, so contextual dates and
amounts follow the panel's configured locale and time zone.

See [Workflow presentations](workflow-presentations.md) for compact date
presets, record templates, scoped catalog tabs, populated previews, and rich
relationship choices. These are presentation declarations over the same final
validation and save operation.
