import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../../domain/foodio_payment.dart';
import '../../../../models/models.dart';
import '../../../people/people_forms.dart';
import '../order_totals.dart';
import '../order_wizard_bindings.dart';

/// Payment method, vouchers, and invoice details step.
BeakWizardStep paymentAndVouchersStep() => BeakWizardStep(
  title: 'Payment & vouchers',
  heading: 'How is it paid?',
  introductionBuilder: (state, _) =>
      '${foodioCompanyPaymentModes.contains(state.asOrder.profile?.paymentMode) ? 'Company invoice' : 'The payment method'} is preselected from the ${state.asOrder.profile?.name.split(' ').first ?? 'selected'} profile. Change it only if ${customerFirstName(state)} pays personally.',
  dependencies: [OrderModel.profile.name, OrderModel.customer.name],
  continueLabel: 'Continue to review',
  spacingInPixels: 24,
  description: 'Payment, cost centre, voucher',
  completedDescription: (state, _) => [
    foodioPaymentLabels[state.asOrder.paymentMode],
    state.asOrder.voucher?.code,
  ].whereType<String>().join(' · '),
  footerHint: 'Next: check everything, then place the order.',
  children: [
    BeakFormLayout(
      spacingInPixels: 16,
      children: [
        OrderModel.paymentMode.inputRadio(
          label: 'Payment method',
          cards: true,
          options: (state) => [
            for (final entry in foodioPaymentLabels.entries)
              if (entry.key == state.asOrder.profile?.paymentMode ||
                  entry.key == 'card' ||
                  entry.key == 'paymentLink')
                BeakInputOption(
                  entry.key,
                  _paymentLabel(state, entry.key, entry.value),
                  description: foodioCompanyPaymentModes.contains(entry.key)
                      ? 'Default for ${state.asOrder.profile?.name ?? 'this profile'}'
                      : entry.key == 'paymentLink'
                      ? '${customerFirstName(state)} pays by link before the kitchen starts'
                      : 'Charged now; not on the company invoice',
                  icon: foodioCompanyPaymentModes.contains(entry.key)
                      ? OiIcons.landmark
                      : entry.key == 'paymentLink'
                      ? OiIcons.link
                      : OiIcons.creditCard,
                ),
          ],
        ),
        OrderModel.paymentMethod.inputCombobox(
          label: 'Saved payment method',
          exclusive: false,
          createLabel: 'Add a payment method',
          createForm: paymentMethodForm(),
          visibleIf: (state) =>
              foodioSavedPaymentModes.contains(state.asOrder.paymentMode),
          options: (state) => PaymentMethodModel.options(
            filter: PaymentMethodModel.kind.eq(
              state.asOrder.paymentMode == 'paypal' ? 'paypal' : 'card',
            ),
          ),
        ),
        BeakColumns(
          children: [
            BeakInput<String>(
              field: OrderModel.costCenter,
              label: 'Cost centre',
              presentation: BeakInputPresentation.select,
              dependencies: [OrderModel.profile.organization.costCenters],
              choices: (state) => [
                for (final centre
                    in (state.read(
                              OrderModel.profile.organization.costCenters,
                            ) ??
                            state.asOrder.costCenter ??
                            '')
                        .split(',')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty))
                  BeakInputOption(centre, centre),
              ],
              description: 'From the company profile; shown on the invoice.',
            ),
            BeakCalculated(
              label: 'Billed on',
              presentation: BeakCalculatedPresentation.field,
              dependencies: [
                OrderModel.profile.organization.invoices,
                OrderModel.deliveryDate,
                OrderModel.paymentMode,
              ],
              value: (state) =>
                  state.asOrder.invoice?.reference ??
                  draftInvoiceForOrder(state)?.reference ??
                  'Assigned when placed',
              description: (state) => draftInvoiceForOrder(state) == null
                  ? 'The invoice is created when the order is placed.'
                  : '${const BeakFormatPolicy(locale: 'en_US', datePattern: 'MMMM').calendarDate(state.asOrder.deliveryDate!)} collective invoice; draft until issued.',
            ),
          ],
        ),
      ],
    ),
    BeakSection(
      title: 'Voucher',
      gapInPixels: 12,
      dividerAfterSpacingInPixels: 12,
      trailing: BeakValueBinding<String>.computed(
        dependencies: const [],
        compute: (_) => 'One voucher per order',
        color: BeakColor.muted,
        textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
      ),
      titleStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      divider: true,
      children: [
        OrderModel.voucher.inputCode(
          label: 'Voucher code',
          codeField: VoucherModel.code,
          normalizeCode: (code) => code.toUpperCase(),
          placeholder: 'e.g. WELCOME10',
          selectionSummary: BeakCalculated(
            value: (state) => money(-orderTotals(state).discountCents),
            format: BeakValueFormat.currency,
            valueStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
          descriptionBuilder: (state) => state.asOrder.voucher == null
              ? 'Vouchers apply to the food subtotal. Delivery fees are excluded.'
              : 'Not combinable with other vouchers. Remove ${state.asOrder.voucher?.code} to use a different code.',
          template: BeakRecordTemplate(
            title: BeakValueBinding.field(
              VoucherModel.code,
              monospace: true,
              strong: true,
            ),
            badges: [
              BeakValueBinding.field(VoucherModel.description, maxLines: null),
            ],
            inlineBadges: true,
          ),
        ),
      ],
    ),
    BeakFormLayout(
      spacingInPixels: 4,
      children: [
        BeakFormLayout(
          spacingInPixels: 24,
          children: [
            const BeakFormDivider(),
            BeakFormLayout(
              spacingInPixels: 12,
              children: [
                OrderModel.sendConfirmation.inputCheckbox(
                  label: 'Send order confirmation to the customer',
                  dependencies: [OrderModel.customer.email],
                  labelBuilder: (state) =>
                      'Send the order confirmation to ${state.asOrder.customer?.email ?? 'the customer'}',
                ),
                BeakCalculated(
                  presentation: BeakCalculatedPresentation.checkbox,
                  labelBuilder: (state) =>
                      'Ask ${state.asOrder.profile?.approver?.name ?? 'the company approver'} for approval',
                  dependencies: [OrderModel.profile.approver.name],
                  value: (_) => true,
                  description: (state) =>
                      'Required: order exceeds the company approval limit.',
                  visibleIf: (state) =>
                      state.asOrder.profile?.kind == 'company' &&
                      orderTotals(state).grossCents >
                          (state.asOrder.profile?.approvalThresholdCents ??
                              4000),
                ),
              ],
            ),
          ],
        ),
        BeakFormLayout(
          spacingInPixels: 20,
          children: [
            const BeakFormDivider(),
            BeakCard(
              title: 'Manual discount, PO number and invoice text',
              disclosurePadding: EdgeInsets.zero,
              headerSubtitle: BeakValueBinding<String>.computed(
                dependencies: [
                  OrderModel.manualDiscountCents,
                  OrderModel.purchaseOrder,
                  OrderModel.invoiceText,
                ],
                compute: (row) =>
                    (row.read(OrderModel.manualDiscountCents) ?? 0) > 0 ||
                        (row.read(OrderModel.purchaseOrder)?.isNotEmpty ??
                            false) ||
                        (row.read(OrderModel.invoiceText)?.isNotEmpty ?? false)
                    ? 'Added'
                    : 'None added',
              ),
              presentation: BeakCardPresentation.plain,
              collapsible: true,
              initiallyExpanded: false,
              children: [
                OrderModel.manualDiscountCents.inputCurrency(
                  label: 'Manual discount',
                  minorUnits: true,
                ),
                OrderModel.purchaseOrder.inputText(
                  label: 'Purchase order (optional)',
                ),
                OrderModel.invoiceText.inputText(label: 'Invoice note'),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
String _paymentLabel(BeakFormReader state, String mode, String fallback) {
  if (mode == 'monthlyInvoice') return 'Company invoice (monthly)';
  if (mode == 'weeklyInvoice') return 'Company invoice (weekly)';
  if (mode == 'card' || mode == 'paypal') {
    final methods =
        (state.read(OrderModel.customer.paymentMethods) ?? const <BeakRecord>[])
            .where(
              (record) =>
                  record.asPaymentMethod.active == true &&
                  record.asPaymentMethod.kind == mode,
            )
            .toList();
    final method =
        methods
            .where((record) => record.asPaymentMethod.isDefault == true)
            .firstOrNull ??
        methods.firstOrNull;
    return method?.asPaymentMethod.name ?? fallback;
  }
  return fallback;
}
