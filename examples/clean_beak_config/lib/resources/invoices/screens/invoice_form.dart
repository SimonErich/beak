import 'package:beak/panel.dart';
import '../../../domain/shop_totals.dart';
import '../../products/models/product.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/invoice_voucher.dart';
import 'invoice_preview.dart';

/// The same sections are used by the invoice wizard and tabbed detail view.
List<BeakWizardStep> invoiceSteps() => invoiceSections().steps;

/// Named sections projected into a wizard, tabs or an ordinary form.
BeakFormSections invoiceSections() => BeakFormSections(
  sections: [
    BeakSection(
      title: 'Customer & document',
      description: 'Choose who to bill and set the invoice dates.',
      children: [
        BeakColumns(
          children: [
            BeakCard(
              title: 'Invoice details',
              children: [
                InvoiceModel.number.inputText(
                  label: 'Invoice number',
                  enabledIf: (state) => !invoiceLocked(state),
                ),
                InvoiceModel.status.input(),
                InvoiceModel.issuedAt.inputDateTime(
                  label: 'Invoice date',
                  enabledIf: (state) => !invoiceLocked(state),
                ),
                InvoiceModel.dueAt.inputDateTime(
                  label: 'Payment due',
                  enabledIf: (state) => !invoiceLocked(state),
                ),
              ],
            ),
            BeakCard(
              title: 'Bill to',
              children: [
                InvoiceModel.customer.inputCombobox(
                  enabledIf: (state) => !invoiceLocked(state),
                ),
                InvoiceModel.order.inputCombobox(
                  enabledIf: (state) => !invoiceLocked(state),
                ),
                InvoiceModel.customerAddress.inputText(
                  label: 'Billing address',
                  enabledIf: (state) => !invoiceLocked(state),
                ),
                const BeakCalculated(
                  label: 'Customer name',
                  value: invoiceCustomerName,
                ),
                const BeakCalculated(
                  label: 'Email',
                  value: invoiceCustomerEmail,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Line items',
      description:
          'Add products, variants, delivery charges or custom services.',
      children: [
        BeakSection(
          title: 'Goods and services',
          description:
              'Prices exclude tax. Leave the product blank for a custom item and enter its description and price.',
          children: [
            InvoiceModel.items.tableForm(
              label: 'Invoice lines',
              minRows: 1,
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              enabledIf: (state) => !invoiceLocked(state),
              children: [
                InvoiceItemModel.product.inputCombobox(
                  options: (state) =>
                      ProductModel.options().including([ProductModel.taxRate]),
                ),
                InvoiceItemModel.variant.inputCombobox(),
                InvoiceItemModel.label.inputText(
                  label: 'Description',
                  description: 'Required for custom items.',
                ),
                InvoiceItemModel.quantity.inputNumber(),
                InvoiceItemModel.unitPrice.inputCurrency(
                  label: 'Net unit price',
                  description: 'Blank uses the catalog price.',
                ),
              ],
              advancedForm: BeakFormLayout(
                children: [
                  BeakColumns(
                    children: [
                      BeakCard(
                        title: 'Description and adjustments',
                        children: [
                          InvoiceItemModel.discount.inputCurrency(
                            label: 'Line discount',
                          ),
                        ],
                      ),
                      BeakCard(
                        title: 'Tax and price',
                        children: [
                          InvoiceItemModel.taxRate.inputCombobox(
                            label: 'Tax rate override',
                          ),
                          const BeakCalculated(
                            label: 'Effective unit price',
                            value: invoiceUnitPrice,
                            format: BeakValueFormat.currency,
                          ),
                          BeakCalculated(
                            label: 'Effective tax rate',
                            value: invoiceTaxPercent,
                            display: (value, formatting) => switch (value) {
                              final BeakDecimal rate =>
                                '${formatting.exactDecimal(rate)} %',
                              _ => formatting.emptyValue,
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Vouchers',
      description: 'Apply more than one voucher in an explicit order.',
      children: [
        BeakCard(
          title: 'Invoice discounts',
          description:
              'Lower positions apply first. Percentage vouchers reduce the remaining subtotal after earlier vouchers.',
          children: [
            InvoiceModel.vouchers.tableForm(
              label: 'Applied vouchers',
              removeBehavior: BeakRemoveBehavior.deleteOwned,
              enabledIf: (state) => !invoiceLocked(state),
              children: [
                InvoiceVoucherModel.position.inputNumber(label: 'Position'),
                InvoiceVoucherModel.voucher.inputCombobox(),
                BeakCalculated(
                  label: 'Saved discount',
                  value: (state) => state.asInvoiceVoucher.discount,
                  format: BeakValueFormat.currency,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Review',
      description: 'Review the amounts, then save the complete invoice.',
      children: invoiceReview(),
    ),
  ],
);

/// Monetary review uses one globally configured format for every amount.
List<BeakFormNode> invoiceReview() => [
  BeakCard(
    title: 'Invoice total',
    description:
        'Line discounts → ordered vouchers → exclusive tax, rounded per line.',
    children: [
      BeakColumns(
        children: [
          BeakCalculated(
            label: 'Subtotal after line discounts',
            format: BeakValueFormat.currency,
            value: (state) => _amount(
              state,
              (preview) => preview.subtotal,
              (record) => record.subtotal,
            ),
          ),
          BeakCalculated(
            label: 'Voucher discounts',
            format: BeakValueFormat.currency,
            value: (state) => _amount(
              state,
              (preview) => preview.discount,
              (record) => record.discount,
            ),
          ),
          BeakCalculated(
            label: 'Tax',
            format: BeakValueFormat.currency,
            value: (state) => _amount(
              state,
              (preview) => preview.tax,
              (record) => record.tax,
            ),
          ),
          BeakCalculated(
            label: 'Amount due',
            format: BeakValueFormat.currency,
            value: (state) => _amount(
              state,
              (preview) => preview.total,
              (record) => record.total,
            ),
          ),
        ],
      ),
      BeakCalculated(
        label: 'Review guidance',
        value: (state) => invoicePreview(state).problem,
        visibleIf: (state) =>
            !invoiceLocked(state) && invoicePreview(state).problem != null,
      ),
    ],
  ),
];

BeakDecimal? _amount(
  BeakFormReader state,
  BeakDecimal Function(ShopTotals) previewValue,
  BeakDecimal? Function(InvoiceDraft) savedValue,
) {
  if ((state.draft.id != null && !state.draft.session.isDirty) ||
      invoiceLocked(state)) {
    return savedValue(state.asInvoice);
  }
  final preview = invoicePreview(state).totals;
  return preview == null ? null : previewValue(preview);
}
