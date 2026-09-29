import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/foodio_clock.dart';
import '../../../models/models.dart';
import 'order_delivery_section.dart';
import '../presentations/order_presentations.dart';
import '../forms/order_totals.dart';

BeakRecordTemplate _customerDetails() => BeakRecordTemplate(
  title: BeakValueBinding.field(
    OrderModel.customer.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
  ),
  avatar: true,
  avatarSize: OiAvatarSize.md,
  avatarPalette: identityPalette,
  identityGapInPixels: 12,
  textGapInPixels: 0,
  detailsGapInPixels: 4,
  inlineSubtitle: true,
  subtitle: [
    BeakValueBinding<String>.computed(
      dependencies: [OrderModel.customer.orders],
      compute: (row) =>
          '${row.read(OrderModel.customer.orders)?.length ?? 0} orders',
    ),
    BeakValueBinding<DateTime>.field(
      OrderModel.customer.joinedAt,
      display: (value, format) => value == null
          ? format.emptyValue
          : 'customer since ${format.date(value, pattern: 'MMM yyyy')}',
    ),
  ],
  details: [
    BeakValueBinding.field(OrderModel.customer.email, icon: OiIcons.mail),
    BeakValueBinding.field(OrderModel.customer.phone, icon: OiIcons.phone),
  ],
);

BeakRecordTemplate _profileDetails() => BeakRecordTemplate(
  title: BeakValueBinding.field(
    OrderModel.profile.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
  ),
  avatar: true,
  avatarSize: OiAvatarSize.md,
  avatarRadius: BorderRadius.circular(10),
  avatarPalette: identityPalette,
  avatarTone: BeakValueBinding<BeakAvatarTone>.computed(
    dependencies: [OrderModel.profile.kind],
    compute: (row) => row.read(OrderModel.profile.kind) == 'company'
        ? identityPalette[1]
        : identityPalette[2],
  ),
  identityGapInPixels: 12,
  textGapInPixels: 0,
  subtitle: [
    BeakValueBinding<String>.computed(
      dependencies: [
        OrderModel.profile.kind,
        OrderModel.profile.role,
        OrderModel.profile.isDefault,
      ],
      compute: (row) => [
        row.read(OrderModel.profile.kind) == 'company'
            ? 'Company profile'
            : 'Private profile',
        row.read(OrderModel.profile.role),
        if (row.read(OrderModel.profile.isDefault) == true) 'default',
      ].whereType<String>().join(' · '),
    ),
  ],
);

/// Customer identity, communication links, and editable delivery profile.
BeakCard orderCustomerProfileCard() => BeakCard(
  title: 'Customer and profile',
  children: [
    BeakFormTemplate(template: _customerDetails()),
    BeakModeLayout(
      read: BeakFormLayout(
        children: [
          BeakFormLayout(
            spacingInPixels: 6,
            children: [
              BeakFormLinks(
                links: [
                  BeakFormLink(
                    label: 'Call',
                    icon: OiIcons.phone,
                    destination: BeakValueBinding<String>.computed(
                      dependencies: [OrderModel.customer.phone],
                      compute: (row) =>
                          switch (row.read(OrderModel.customer.phone)) {
                            final String phone when phone.trim().isNotEmpty =>
                              Uri(scheme: 'tel', path: phone).toString(),
                            _ => null,
                          },
                    ),
                  ),
                  BeakFormLink(
                    label: 'Email',
                    icon: OiIcons.mail,
                    destination: BeakValueBinding<String>.computed(
                      dependencies: [OrderModel.customer.email],
                      compute: (row) =>
                          switch (row.read(OrderModel.customer.email)) {
                            final String email when email.trim().isNotEmpty =>
                              Uri(scheme: 'mailto', path: email).toString(),
                            _ => null,
                          },
                    ),
                  ),
                ],
              ),
              BeakFormTemplate(
                template: BeakRecordTemplate(
                  title: BeakValueBinding.field(
                    OrderModel.customer.preferences,
                    color: BeakColor.muted,
                    textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                    maxLines: null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      edit: BeakFormLayout(
        children: [
          BeakFormLock(
            label: 'Change customer',
            description: 'Orders already in the kitchen keep their customer.',
            visibleIf: (state) => !orderIdentityEditable(state),
          ),
        ],
      ),
    ),
    const BeakFormDivider(),
    BeakModeLayout(
      read: _profileRead(),
      edit: BeakFormLayout(
        children: [
          OrderModel.customer.inputCombobox(
            label: 'Customer',
            visibleIf: orderIdentityEditable,
            template: customerIdentity(),
          ),
          OrderModel.profile.inputCombobox(
            label: 'Profile',
            enabledIf: orderIdentityEditable,
            validate: const [BeakRequired()],
            description:
                "The kitchen has started, so the delivery profile can't change.",
            template: BeakRecordTemplate(
              title: BeakValueBinding<String>.computed(
                dependencies: [
                  DeliveryProfileModel.name,
                  DeliveryProfileModel.role,
                ],
                compute: (row) =>
                    [
                          row.read(DeliveryProfileModel.name),
                          row.read(DeliveryProfileModel.role),
                        ]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' · '),
              ),
            ),
            options: (state) => DeliveryProfileModel.options(
              filter: DeliveryProfileModel.customerId.eq(
                state.asOrder.customerId ?? '',
              ),
            ),
          ),
        ],
      ),
    ),
    BeakModeLayout(
      read: BeakFormLayout(
        spacingInPixels: 2,
        children: [
          BeakCalculated(
            label: 'Payment method',
            presentation: BeakCalculatedPresentation.detail,
            value: (state) =>
                '${paymentLabels[state.asOrder.paymentMode] ?? '—'} · monthly collective',
          ),
          BeakFormTemplate(
            visibleIf: (state) => state.asOrder.invoiceId != null,
            template: BeakRecordTemplate(
              textGapInPixels: 0,
              inlineBadges: true,
              title: BeakValueBinding.field(
                OrderModel.invoice.reference,
                label: 'Billed on',
                color: BeakColor.primary,
                textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
              ),
              badges: [
                BeakValueBinding.field(
                  OrderModel.invoice.status,
                  badge: true,
                  badgeDot: true,
                ),
              ],
            ),
          ),
        ],
      ),
      edit: BeakFormLayout(
        children: [
          OrderModel.paymentMode.inputSelect(
            label: 'Payment method',
            options: (_) => [
              for (final entry in paymentLabels.entries)
                BeakInputOption(entry.key, entry.value),
            ],
          ),
        ],
      ),
    ),
    BeakModeLayout(
      read: BeakFormLayout(
        children: [
          BeakCalculated(
            label: 'Cost centre',
            presentation: BeakCalculatedPresentation.detail,
            value: (state) => state.asOrder.costCenter,
            dependencies: [OrderModel.profile.name],
            description: (state) =>
                'Required by ${state.asOrder.profile?.name ?? 'the company'}',
          ),
        ],
      ),
      edit: BeakFormLayout(
        children: [
          OrderModel.costCenter.inputText(
            label: 'Cost centre',
            description: 'Required by the company · appears on the invoice.',
          ),
        ],
      ),
    ),
    BeakFormLayout(
      spacingInPixels: 0,
      children: [
        BeakFormCapacity(
          label: 'Budget this month',
          valueStyle: const TextStyle(fontSize: 14, height: 10 / 7),
          heightInPixels: 8,
          gapInPixels: 6,
          labelStyle: const TextStyle(
            fontSize: 12,
            height: 4 / 3,
            fontWeight: FontWeight.w400,
          ),
          dependencies: [
            OrderModel.profile.budgets,
            OrderModel.budgetReserved,
            OrderModel.budgetAmountCents,
          ],
          visibleIf: (state) => budgetFor(state) != null,
          value: (state) => projectedBudgetUsed(state) / 100,
          max: (state) => (budgetFor(state)?.allowanceCents ?? 0) / 100,
          format: BeakValueFormat.currency,
          valueLabel: (state, format) =>
              '${format.currency(((budgetFor(state)?.allowanceCents ?? 0) - projectedBudgetUsed(state)) / 100)} left',
          caption: (state, format) {
            final current = orderTotals(state).grossCents;
            final before =
                OrderModel.grossCents.readFrom(state.draft.initialRecord) ??
                current;
            final delta = current - before;
            return '${format.currency(projectedBudgetUsed(state) / 100)} of ${format.currency((budgetFor(state)?.allowanceCents ?? 0) / 100)} used${delta == 0 ? ', incl. this order' : ' · ${format.currency(delta / 100)} not saved yet'}';
          },
        ),
        BeakModeLayout(
          read: BeakFormLayout(children: [orderApprovalNotice(editing: false)]),
          edit: BeakFormLayout(children: [orderApprovalNotice(editing: true)]),
        ),
      ],
    ),
  ],
);

/// Approval threshold status shown beside budget calculations.
BeakCalculated orderApprovalNotice({required bool editing}) => BeakCalculated(
  valueStyle: const TextStyle(fontSize: 12, height: 4 / 3),
  dependencies: [
    OrderModel.profile.approvalThresholdCents,
    OrderModel.profile.approver.name,
  ],
  value: (state) => (
    state.asOrder.profile?.approvalThresholdCents ?? 0,
    orderTotals(state).grossCents <=
        (state.asOrder.profile?.approvalThresholdCents ?? 0),
    state.asOrder.profile?.approver?.name ?? 'the company approver',
  ),
  display: (value, format) => switch (value) {
    (final int threshold, final bool within, final String approver) =>
      editing
          ? within
                ? 'Still under the ${format.currency(threshold / 100, precision: threshold % 100 == 0 ? 0 : 2)} approval limit'
                : 'Needs approval by $approver'
          : 'Over ${format.currency(threshold / 100, precision: threshold % 100 == 0 ? 0 : 2)} needs approval by $approver',
    _ => format.emptyValue,
  },
);

BeakFormLayout _profileRead() => BeakFormLayout(
  spacingInPixels: 6,
  children: [
    BeakFormTemplate(
      template: BeakRecordTemplate(
        title: BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'Profile',
          color: BeakColor.muted,
          textStyle: const TextStyle(fontSize: 12, height: 4 / 3),
        ),
      ),
    ),
    BeakFormTemplate(template: _profileDetails()),
  ],
);

BeakRelationAdd _addDish({bool search = false}) => BeakRelationAdd(
  field: OrderModel.items,
  label: 'Add a dish',
  caption: search ? null : 'until 10:30',
  presentation: search
      ? BeakRelationAddPresentation.search
      : BeakRelationAddPresentation.dashed,
  placeholder: search ? 'Add a dish, e.g. Falafel wrap' : null,
  enabledIf: (state) => !const FoodioClock().changesClosed(
    state.asOrder.deliveryDate ?? const FoodioClock().today,
  ),
);

/// Add-item controls and a tax-aware order total under the items relation.
BeakColumns orderDetailItemsFooter() => BeakColumns(
  minColumnWidthInPixels: 220,
  gapInPixels: 24,
  columnWidths: const [null, 248],
  padding: const EdgeInsetsDirectional.only(end: 44),
  children: [
    BeakFormLayout(
      spacingInPixels: 12,
      children: [
        BeakModeLayout(
          read: BeakFormLayout(children: [_addDish()]),
          edit: BeakFormLayout(children: [_addDish(search: true)]),
        ),
        BeakFormNotice(
          tone: BeakColor.warning,
          dependencies: [
            OrderModel.customer.firstName,
            OrderModel.customer.allergens,
          ],
          visibleIf: (state) =>
              (state.asOrder.customer?.allergens ?? '').isNotEmpty,
          titleBuilder: (state) =>
              "${state.asOrder.customer?.firstName ?? 'Customer'}'s allergen alert: ${state.asOrder.allergenNote ?? state.asOrder.customer?.allergens}",
          message: (state) {
            final allergens = (state.asOrder.customer?.allergens ?? '')
                .split(',')
                .map((code) => code.trim())
                .toSet();
            final matching = state
                .rows(OrderModel.items)
                .where(
                  (row) => (row.asOrderItem.allergens ?? '')
                      .split(',')
                      .any((code) => allergens.contains(code.trim())),
                )
                .map((row) => row.asOrderItem.label?.split(' with ').first)
                .whereType<String>()
                .toList();
            return matching.isEmpty
                ? 'Check each dish and preparation note before preparing this order.'
                : '${matching.join(', ')} contains ${allergens.join(', ')}. The customer left a note — please check.';
          },
        ),
      ],
    ),
    BeakFormSummary(
      gapInPixels: 2,
      lines: [
        BeakSummaryLine(
          label: 'Subtotal',
          value: (state) => money(orderTotals(state).subtotalCents),
          format: BeakValueFormat.currency,
        ),
        BeakSummaryLine(
          label: 'Discounts',
          visibleIf: (state) => orderTotals(state).discountCents != 0,
          value: (state) => money(-orderTotals(state).discountCents),
          format: BeakValueFormat.currency,
        ),
        BeakSummaryLine(
          label: 'Delivery framework agreement',
          value: (_) => money(0),
          format: BeakValueFormat.currency,
          labelStyle: const TextStyle(fontSize: 12, height: 20 / 12),
        ),
        BeakSummaryLine(
          label: 'Net',
          value: (state) => money(orderTotals(state).netCents),
          format: BeakValueFormat.currency,
        ),
        BeakSummaryLine(
          label: 'VAT 10%',
          value: (state) => money(orderTotals(state).taxByRate[1000] ?? 0),
          format: BeakValueFormat.currency,
        ),
        BeakSummaryLine(
          label: 'VAT 20%',
          value: (state) => money(orderTotals(state).taxByRate[2000] ?? 0),
          format: BeakValueFormat.currency,
        ),
        BeakSummaryLine(
          label: 'Total',
          value: (state) => money(orderTotals(state).grossCents),
          format: BeakValueFormat.currency,
          emphasized: true,
          dividerBefore: true,
          dividerSpacingInPixels: 6,
          valueCaption: (state, format) {
            final before = OrderModel.grossCents.readFrom(
              state.draft.initialRecord,
            );
            return before == null || before == orderTotals(state).grossCents
                ? null
                : 'was ${format.currency(before / 100)}';
          },
          labelStyle: const TextStyle(fontSize: 16, height: 1.5),
          valueStyle: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    ),
  ],
);
