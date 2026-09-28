import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';
import '../../models/models.dart';
import '../../domain/foodio_payment.dart';
import '../../domain/foodio_clock.dart';
import 'order_presentations.dart';
import 'order_items.dart';
import 'order_summary.dart';
import 'order_totals.dart';
import 'order_review.dart';
import '../people/people_forms.dart';

export 'order_items.dart';
export 'order_summary.dart';

/// Five stages over one draft; the final action saves the complete order graph.
BeakWizardScreen orderWizard() => BeakWizardScreen(
  roles: const {BeakScreenRole.create},
  fullScreen: true,
  navigation: BeakWizardNavigation.rail,
  navigationDescription:
      "Places an order on a customer's behalf, for example during a phone call.",
  header: const BeakFormHeader(title: 'New order'),
  submitAction: 'place',
  submitLabel: 'Place order',
  drafts: const BeakFormDrafts(
    store: BeakBrowserDraftStore(),
    key: 'foodio-order',
    context: 'foodio-demo:marie-novak',
    schemaVersion: 1,
  ),
  aside: BeakFormLayout(children: [orderSummary(), orderReviewAside()]),
  asideFooter: orderSummaryFooter(),
  steps: [
    BeakWizardStep(
      title: 'Customer & profile',
      heading: 'Who is this order for?',
      introduction:
          'Search a customer, then choose the profile to order with. The profile decides who pays and where the food goes.',
      spacing: 24,
      continueLabel: 'Continue to delivery',
      description: 'Search, then choose a profile',
      completedDescription: (state, _) => [
        state.asOrder.customer?.name,
        state.asOrder.profile?.name,
      ].whereType<String>().join(' · '),
      footerHint: 'Delivery and payment are filled in from this profile.',
      children: [
        OrderModel.customer.inputSearch(
          template: customerIdentity(),
          exclusive: false,
          createLabel: 'Create a new customer',
          createIcon: OiIcons.userRoundPlus,
          createDescription: 'Not in the list? Add them first, then come back.',
          createForm: customerForm(),
          searchSources: [
            CustomerModel.name,
            CustomerModel.email,
            CustomerModel.phone,
            CustomerModel.profiles.search(
              DeliveryProfileModel.organization.name,
            ),
          ],
          label: 'Customer',
          description: 'Search by name, email, phone number or company.',
          validate: const [BeakRequired()],
        ),
        OrderModel.profile.inputCards(
          template: profileIdentity(),
          exclusive: false,
          createLabel: 'Add a profile',
          createLabelBuilder: (state) =>
              'Add a profile for ${_customerFirstName(state)}',
          createForm: deliveryProfileForm(),
          label: 'Profile',
          description:
              'The default is selected. Delivery and payment follow this profile.',
          descriptionBuilder: (state) {
            final count = state.read(OrderModel.customer.profiles)?.length ?? 0;
            return '${_customerFirstName(state)} has $count ${count == 1 ? 'profile' : 'profiles'}. The default is selected.';
          },
          dependencies: [
            OrderModel.customer.name,
            OrderModel.customer.profiles,
          ],
          divider: true,
          validate: const [BeakRequired()],
          options: (state) => DeliveryProfileModel.options(
            filter: DeliveryProfileModel.customerId.eq(
              state.asOrder.customerId ?? '',
            ),
          ),
        ),
      ],
    ),
    BeakWizardStep(
      title: 'Delivery',
      heading: 'When and where should it arrive?',
      introductionBuilder: (state, _) =>
          "The location and delivery method come from ${_customerFirstName(state)}'s profile. Pick the day and a slot with free capacity.",
      dependencies: [OrderModel.customer.name],
      spacing: 24,
      continueLabel: 'Continue to dishes',
      description: 'Date, slot and location',
      completedDescription: (state, format) => [
        if (state.asOrder.deliveryDate != null)
          format.format(state.asOrder.deliveryDate, BeakValueFormat.date),
        state.asOrder.slot?.name,
        state.asOrder.location?.name,
      ].whereType<String>().join(' · '),
      footerHintBuilder: (state, format) =>
          '${format.date((state.asOrder.deliveryDate ?? const FoodioClock().today).toDateTime(), pattern: 'EEEE')}’s kitchen prep list is generated the day before at 16:00.',
      children: [
        BeakSection(
          title: 'Delivery date',
          titleStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
          gap: 8,
          trailing: BeakValueBinding<String>.computed(
            dependencies: const [],
            compute: (_) => 'Same-day orders close at 10:30.',
            icon: OiIcons.clock,
            color: BeakColor.muted,
            textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
          ),
          children: [
            OrderModel.deliveryDate.inputDate(
              label: '',
              validate: const [BeakRequired()],
              shortcuts: (_) {
                const clock = FoodioClock();
                BeakDate after(int days) => BeakDate.fromDateTime(
                  clock.local.add(Duration(days: days)),
                );
                const dates = BeakFormatPolicy(
                  locale: 'en_US',
                  datePattern: 'EEE d MMM',
                );
                return [
                  BeakInputOption(
                    clock.today,
                    'Today',
                    enabled: !clock.changesClosed(clock.today),
                  ),
                  BeakInputOption(
                    after(1),
                    'Tomorrow · ${dates.calendarDate(after(1))}',
                  ),
                  BeakInputOption(after(2), dates.calendarDate(after(2))),
                ];
              },
            ),
          ],
        ),
        BeakFormLayout(
          spacing: 8,
          children: [
            OrderModel.slot.inputCards(
              selectDefaultOption: true,
              defaultOptionMatch: (option, state) {
                final start = state.read(
                  OrderModel.profile.preferredDeliveryStart,
                );
                final end = state.read(OrderModel.profile.preferredDeliveryEnd);
                return start != null &&
                    end != null &&
                    DeliverySlotModel.startMinute.readFrom(option) ==
                        start.hour * 60 + start.minute &&
                    DeliverySlotModel.endMinute.readFrom(option) ==
                        end.hour * 60 + end.minute;
              },
              compact: true,
              minCardWidth: 115,
              template: BeakRecordTemplate(
                title: BeakValueBinding.field(DeliverySlotModel.name),
                progressHeight: 8,
                progressStriped: true,
                details: [
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      DeliverySlotModel.capacity,
                      DeliverySlotModel.reservedOrders,
                      DeliverySlotModel.active,
                    ],
                    visibleIf: (row) =>
                        row.read(DeliverySlotModel.active) == true,
                    tone: (row) => _slotNearCapacity(row)
                        ? BeakColor.warning
                        : BeakColor.muted,
                    iconFor: (row) =>
                        _slotNearCapacity(row) ? OiIcons.triangleAlert : null,
                    textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                    compute: (row) =>
                        '${((row.read(DeliverySlotModel.capacity) ?? 0) - (row.read(DeliverySlotModel.reservedOrders) ?? 0)).clamp(0, 99999)} left',
                  ),
                ],
                progress: BeakValueBinding<num>.computed(
                  dependencies: [
                    DeliverySlotModel.capacity,
                    DeliverySlotModel.reservedOrders,
                  ],
                  compute: (row) {
                    final capacity = row.read(DeliverySlotModel.capacity) ?? 0;
                    return capacity == 0
                        ? 0
                        : (row.read(DeliverySlotModel.reservedOrders) ?? 0) /
                              capacity;
                  },
                ),
              ),
              disabledReason: (row, _) =>
                  DeliverySlotModel.active.readFrom(row) != true
                  ? 'Not available'
                  : (DeliverySlotModel.reservedOrders.readFrom(row) ?? 0) >=
                        (DeliverySlotModel.capacity.readFrom(row) ?? 0)
                  ? 'This delivery slot is full'
                  : null,
              label: 'Delivery slot',
              descriptionInline: true,
              descriptionBuilder: (state) =>
                  'Capacity for ${const BeakFormatPolicy(locale: 'en_US', datePattern: 'EEE d MMM').calendarDate(state.asOrder.deliveryDate ?? const FoodioClock().today)} · selected profile route ${state.asOrder.profile?.location?.routeCode ?? '—'}',
              dependencies: [
                OrderModel.deliveryDate,
                OrderModel.profile.location.routeCode,
                OrderModel.profile.location.method,
                OrderModel.profile.preferredDeliveryStart,
                OrderModel.profile.preferredDeliveryEnd,
              ],
              validate: const [BeakRequired()],
              enabledIf: (state) => state.asOrder.deliveryDate != null,
              options: (state) => DeliverySlotModel.options(
                filter: BeakAndFilter([
                  DeliverySlotModel.date.eq(
                    state.asOrder.deliveryDate ?? const FoodioClock().today,
                  ),
                  DeliverySlotModel.method.eq(
                    state.read(OrderModel.profile.location.method) ?? 'office',
                  ),
                ]),
              ),
            ),
            const BeakCalculated(
              value: _slotReservationHint,
              valueStyle: TextStyle(fontSize: 12, height: 4 / 3),
            ),
          ],
        ),
        BeakSection(
          title: 'Location',
          gap: 12,
          dividerAfterSpacing: 14,
          trailing: BeakValueBinding<String>.computed(
            dependencies: [OrderModel.profile.organization.name],
            compute: (row) =>
                'Delivery locations of ${row.read(OrderModel.profile.organization.name) ?? 'this profile'}',
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
            OrderModel.location.inputCards(
              cardPadding: const EdgeInsets.all(17),
              defaultOption: OrderModel.profile.location,
              dependencies: [OrderModel.profile.location],
              template: BeakRecordTemplate(
                textGap: 2,
                title: BeakValueBinding.field(
                  DeliveryLocationModel.name,
                  strong: true,
                ),
                subtitle: [
                  BeakValueBinding.field(
                    DeliveryLocationModel.handover,
                    maxLines: 2,
                  ),
                  BeakValueBinding<String>.computed(
                    dependencies: [
                      DeliveryLocationModel.street,
                      DeliveryLocationModel.postalCode,
                      DeliveryLocationModel.city,
                    ],
                    compute: (row) =>
                        '${row.read(DeliveryLocationModel.street)}, ${row.read(DeliveryLocationModel.postalCode)} ${row.read(DeliveryLocationModel.city)}',
                    maxLines: 2,
                  ),
                ],
              ),
              options: (state) => DeliveryLocationModel.options(
                filter: BeakAndFilter([
                  if (state.asOrder.profile?.organizationId
                      case final organization?)
                    DeliveryLocationModel.organizationId.eq(organization)
                  else
                    DeliveryLocationModel.id.eq(
                      state.asOrder.profile?.locationId ?? '',
                    ),
                  DeliveryLocationModel.active.eq(true),
                ]),
              ),
              label: '',
              validate: const [BeakRequired()],
            ),
            BeakFormNotice(
              tone: BeakColor.muted,
              icon: OiIcons.truck,
              dependencies: [
                OrderModel.location.method,
                OrderModel.location.routeCode,
                OrderModel.location.handover,
              ],
              message: (state) =>
                  'Handover and transport: ${state.read(OrderModel.location.method) == 'office' ? 'Office delivery' : 'Home delivery'} · ${_transport(state.read(OrderModel.location.routeCode))}',
              caption: (_) => 'Set by the location',
              captionIcon: OiIcons.lock,
            ),
            BeakFormLayout(
              spacing: 24,
              children: [
                BeakCard(
                  presentation: BeakCardPresentation.plain,
                  title: 'Deliver to a different address this once',
                  description:
                      'Only for this order; the profile stays as it is.',
                  collapsible: true,
                  disclosurePadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  children: [
                    OrderModel.addressOverride.inputToggle(
                      label: 'Use a one-time delivery address',
                    ),
                    BeakFormLayout(
                      visibleIf: (state) =>
                          state.asOrder.addressOverride == true,
                      children: [
                        BeakFormNotice(
                          plain: true,
                          tone: BeakColor.muted,
                          message: (_) =>
                              'The address must remain in this location’s city and postal area.',
                        ),
                        OrderModel.street.inputText(
                          label: 'Street and house number',
                          validate: const [BeakRequired()],
                        ),
                        BeakColumns(
                          children: [
                            OrderModel.postalCode.inputText(
                              label: 'Postal code',
                              validate: const [BeakRequired()],
                            ),
                            OrderModel.city.inputText(
                              label: 'City',
                              validate: const [BeakRequired()],
                            ),
                          ],
                        ),
                        OrderModel.handover.inputText(
                          label: 'Handover instructions',
                        ),
                      ],
                    ),
                  ],
                ),
                BeakSection(
                  title: 'Delivery note (optional)',
                  titleStyle: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  gap: 6,
                  children: [
                    OrderModel.deliveryNote.inputText(
                      label: '',
                      description:
                          'Printed on the delivery note for the driver.',
                      maxLines: 3,
                      controlHeight: 88,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    BeakWizardStep(
      title: 'Dishes',
      heading: 'Choose dishes',
      introductionBuilder: (state, format) =>
          'From the menu plan ${state.asOrder.profile?.menuPlan?.name ?? 'for this profile'} for ${format.date((state.asOrder.deliveryDate ?? const FoodioClock().today).toDateTime(), pattern: 'EEE d MMM')}.',
      dependencies: [OrderModel.profile.menuPlan.name, OrderModel.deliveryDate],
      spacing: 24,
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
          visibleIf: (state) =>
              (state.asOrder.customerNote?.isNotEmpty ?? false),
        ),
      ],
    ),
    BeakWizardStep(
      title: 'Payment & vouchers',
      heading: 'How is it paid?',
      introductionBuilder: (state, _) =>
          '${foodioCompanyPaymentModes.contains(state.asOrder.profile?.paymentMode) ? 'Company invoice' : 'The payment method'} is preselected from the ${state.asOrder.profile?.name.split(' ').first ?? 'selected'} profile. Change it only if ${_customerFirstName(state)} pays personally.',
      dependencies: [OrderModel.profile.name, OrderModel.customer.name],
      continueLabel: 'Continue to review',
      spacing: 24,
      description: 'Payment, cost centre, voucher',
      completedDescription: (state, _) => [
        foodioPaymentLabels[state.asOrder.paymentMode],
        state.asOrder.voucher?.code,
      ].whereType<String>().join(' · '),
      footerHint: 'Next: check everything, then place the order.',
      children: [
        BeakFormLayout(
          spacing: 16,
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
                          ? '${_customerFirstName(state)} pays by link before the kitchen starts'
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
                  description:
                      'From the company profile; shown on the invoice.',
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
          gap: 12,
          dividerAfterSpacing: 12,
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
                  BeakValueBinding.field(
                    VoucherModel.description,
                    maxLines: null,
                  ),
                ],
                inlineBadges: true,
              ),
            ),
          ],
        ),
        BeakFormLayout(
          spacing: 4,
          children: [
            BeakFormLayout(
              spacing: 24,
              children: [
                const BeakFormDivider(),
                BeakFormLayout(
                  spacing: 12,
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
              spacing: 20,
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
                            (row.read(OrderModel.invoiceText)?.isNotEmpty ??
                                false)
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
    ),
    orderReviewStep(),
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

String _customerFirstName(BeakFormReader state) =>
    (state.asOrder.customer?.name ?? 'the customer').split(' ').first;

String _transport(String? route) =>
    (route ?? '').toLowerCase().startsWith('bike')
    ? 'Bike courier'
    : 'Cooled van · Route ${route ?? '—'}';

String _slotReservationHint(BeakFormReader _) =>
    'Unavailable slots cannot be selected. Capacity is reserved when the order is placed.';

bool _slotNearCapacity(BeakDraftReader row) {
  final capacity = row.read(DeliverySlotModel.capacity) ?? 0;
  return capacity > 0 &&
      (row.read(DeliverySlotModel.reservedOrders) ?? 0) / capacity >= .9;
}
