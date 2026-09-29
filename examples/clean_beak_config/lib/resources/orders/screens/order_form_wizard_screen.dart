import 'package:beak/panel.dart';
import '../../../domain/shop_totals.dart';
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
          summary: (rows) => rows.fold<BeakDecimal>(
            ShopMoney.zero,
            (total, row) => total + lineTotal(row),
          ),
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
              summary: (rows) => rows.fold<BeakDecimal>(
                ShopMoney.zero,
                (sum, row) =>
                    sum + (row.asOrderDiscount.amount ?? ShopMoney.zero),
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
                          .fold(
                            ShopMoney.zero,
                            (sum, row) => sum + lineTotal(row),
                          ) -
                      state
                          .rows(OrderModel.discounts)
                          .fold(
                            ShopMoney.zero,
                            (sum, row) =>
                                sum +
                                (row.asOrderDiscount.amount ?? ShopMoney.zero),
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
BeakDecimal lineTotal(BeakFormReader state) {
  final item = state.asOrderItem;
  final unitPrice =
      item.overwritePrice ??
      item.variant?.price ??
      item.product?.price ??
      ShopMoney.zero;
  return unitPrice * (item.quantity ?? 0) - (item.discount ?? ShopMoney.zero);
}
