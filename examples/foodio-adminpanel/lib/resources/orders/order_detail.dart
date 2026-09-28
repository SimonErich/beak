import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../domain/_order_note_input.dart';
import '../../domain/foodio_clock.dart';
import '../../theme/gabel_theme.dart';
import 'package:flutter/widgets.dart';

import '../../models/models.dart';
import 'order_form.dart';
import 'order_presentations.dart';
import 'order_totals.dart';

/// The detail and edit routes share one graph and the same section definitions.
BeakFormScreen orderDetailAndEdit() => BeakFormScreen(
  roles: const {BeakScreenRole.read, BeakScreenRole.edit},
  submitLabel: 'Save changes',
  submitIcon: OiIcons.check,
  outlinedCancel: true,
  showActionsWhileEditing: false,
  submitAction: 'amend',
  editLabel: 'Edit order',
  editingLabel: 'Editing',
  prominentEdit: true,
  compactActions: true,
  showChangeBar: true,
  showBack: false,
  pagePadding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
  pageGap: 24,
  asideFraction: 1 / 3,
  recordHeader: BeakRecordTemplate(
    icon: const BeakValueBinding<IconData>.computed(
      dependencies: [],
      compute: _orderIcon,
    ),
    iconSize: 56,
    identityGap: 16,
    copyableTitle: true,
    title: BeakValueBinding.field(
      OrderModel.reference,
      strong: true,
      monospace: true,
      textStyle: const TextStyle(
        fontSize: 30,
        height: 40 / 30,
        fontWeight: FontWeight.w500,
        letterSpacing: -.3,
      ),
    ),
    badges: [orderStatus()],
    subtitle: [
      BeakValueBinding.field(OrderModel.customer.name),
      BeakValueBinding.field(OrderModel.profile.name),
      BeakValueBinding<DateTime>.field(
        OrderModel.placedAt,
        display: (value, format) => value == null
            ? format.emptyValue
            : 'placed ${format.date(value) == format.date(const FoodioClock().now) ? 'today ${format.time(value)}' : format.dateTime(value)}',
      ),
      BeakValueBinding.field(OrderModel.source, label: 'via'),
    ],
  ),
  header: BeakFormLayout(
    spacing: 24,
    children: [
      BeakModeLayout(
        read: BeakFormLayout(children: [_changeNotice(editing: false)]),
        edit: BeakFormLayout(children: [_changeNotice(editing: true)]),
      ),
      BeakFormMetrics(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        gap: 4,
        metrics: [
          BeakFormMetric(
            valueStyle: gabelNumericMetricStyle,
            label: 'Total',
            value: (state) => money(orderTotals(state).grossCents),
            format: BeakValueFormat.currency,
            flex: 7,
            subtitle: (state, format) {
              final total = orderTotals(state);
              final before = OrderModel.grossCents.readFrom(
                state.draft.initialRecord,
              );
              final delta = total.grossCents - (before ?? total.grossCents);
              return '${delta == 0 ? '' : '${delta > 0 ? '+' : '−'}${format.currency(delta.abs() / 100)} · '}incl. ${format.currency(total.taxCents / 100)} VAT';
            },
          ),
          BeakFormMetric(
            valueStyle: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
            label: 'Delivery',
            flex: 7,
            value: (state) =>
                '${state.asOrder.deliveryDate == const FoodioClock().today ? 'Today, ' : ''}${state.asOrder.slot?.name ?? '—'}',
            dependencies: [OrderModel.slot.name, OrderModel.deliveryDate],
            subtitle: (state, _) {
              final before = OrderModel.slot.name.readFrom(
                state.draft.initialRecord,
              );
              return before != null && before != state.asOrder.slot?.name
                  ? 'was $before'
                  : _deliveryMethod(state.asOrder.deliveryMethod);
            },
          ),
          BeakFormMetric(
            valueStyle: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
            label: 'Payment',
            value: (state) => paymentLabels[state.asOrder.paymentMode],
            flex: 7,
            dependencies: [OrderModel.invoice.reference],
            subtitle: (state, _) => state.asOrder.invoice?.reference == null
                ? 'Payment on order'
                : 'on ${state.asOrder.invoice!.reference}',
          ),
          BeakFormMetric(
            valueStyle: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
            label: 'Profile',
            flex: 8,
            value: (state) => state.asOrder.profile?.name,
            dependencies: [OrderModel.profile.name, OrderModel.profile.role],
            subtitle: (state, _) =>
                '${state.asOrder.profile?.role ?? 'Customer'} · cost centre ${state.asOrder.costCenter?.split(' ').first ?? '—'}',
          ),
          BeakFormMetric(
            valueStyle: gabelNumericMetricStyle,
            label: 'Budget left',
            value: (state) => money(
              (budgetFor(state)?.allowanceCents ?? 0) -
                  projectedBudgetUsed(state),
            ),
            format: BeakValueFormat.currency,
            dependencies: [OrderModel.profile.budgets],
            flex: 7,
            subtitle: (state, format) {
              final current = orderTotals(state).grossCents;
              final before =
                  OrderModel.grossCents.readFrom(state.draft.initialRecord) ??
                  current;
              final left =
                  (budgetFor(state)?.allowanceCents ?? 0) -
                  projectedBudgetUsed(state);
              return 'of ${format.currency((budgetFor(state)?.allowanceCents ?? 0) / 100)}${current == before ? ' this month' : ' · was ${format.currency((left + current - before) / 100)}'}';
            },
          ),
        ],
      ),
    ],
  ),
  aside: BeakFormLayout(
    spacing: 24,
    children: [
      _customerProfileCard(),
      BeakCard(
        title: 'Notes',
        children: [
          BeakCalculated(
            label: 'Customer note',
            labelBuilder: (state) =>
                'Customer note · from ${state.asOrder.customer?.name ?? 'the customer'} at checkout',
            value: (state) => state.asOrder.customerNote?.isNotEmpty == true
                ? '“${state.asOrder.customerNote}”'
                : null,
            dependencies: [OrderModel.customerNote, OrderModel.customer.name],
            presentation: BeakCalculatedPresentation.message,
          ),
          BeakFormTimeline(
            field: OrderModel.notes,
            title: OrderNoteModel.author,
            description: OrderNoteModel.body,
            time: OrderNoteModel.occurredAt,
            messages: true,
            emphasizeMentions: true,
            messageIdentity: BeakRecordTemplate(
              title: BeakValueBinding.field(
                OrderNoteModel.author,
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              avatar: true,
              avatarSize: OiAvatarSize.xs,
              inlineIdentity: true,
              avatarPalette: identityPalette,
              identityGap: 8,
              textGap: 0,
              inlineSubtitle: true,
              subtitle: [
                BeakValueBinding.field(
                  OrderNoteModel.authorRole,
                  visibleIf: (row) =>
                      row.read(OrderNoteModel.authorRole) != null,
                ),
                BeakValueBinding<DateTime>.field(
                  OrderNoteModel.occurredAt,
                  display: (value, format) => value == null
                      ? format.emptyValue
                      : 'today ${format.time(value)}',
                ),
              ],
            ),
          ),
          BeakFormActionInput(
            name: 'addNote',
            submitWithForm: 'amend',
            optionalWithForm: true,
            description: 'Only staff can see internal notes.',
            editDescription: 'Saved with your other changes',
            inlineFooter: true,
            footerMinHeight: 32,
            layout: BeakFormLayout(
              children: [
                OrderNoteInputModel.body.inputText(
                  label: 'New internal note',
                  placeholder:
                      'Add an internal note — type @ to mention a colleague',
                  maxLines: 2,
                  showCounter: false,
                ),
              ],
            ),
          ),
        ],
      ),
      BeakCard(
        title: 'Support details',
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        collapseLeading: true,
        headerSubtitle: BeakValueBinding<String>.computed(
          dependencies: const [],
          compute: (_) => 'Order ID, device, API source',
        ),
        collapsible: true,
        initiallyExpanded: false,
        children: [
          OrderModel.reference.inputText(readOnly: true),
          OrderModel.source.inputText(readOnly: true),
          OrderModel.clientInfo.inputText(
            label: 'Device and API source',
            readOnly: true,
          ),
        ],
      ),
    ],
  ),
  layout: BeakFormLayout(
    showChangeIndicators: true,
    children: [
      BeakTabs(
        acrossRegions: true,
        tabs: [
          BeakTab(
            title: 'Overview',
            showValidationBadge: false,
            spacing: 24,
            children: [
              BeakCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                children: [
                  BeakFormProgress(
                    field: OrderModel.status,
                    steps: [
                      BeakProgressStep(
                        label: 'Placed',
                        details: BeakRecordTemplate(
                          textGap: 0,
                          title: BeakValueBinding.field(
                            OrderModel.placedAt.formatted(BeakValueFormat.time),
                          ),
                          subtitle: [
                            BeakValueBinding<String>.computed(
                              dependencies: [
                                OrderModel.customer.name,
                                OrderModel.createdBy,
                              ],
                              compute: (row) =>
                                  'by ${row.read(OrderModel.createdBy) == 'Customer' ? row.read(OrderModel.customer.name) : row.read(OrderModel.createdBy)}',
                            ),
                          ],
                        ),
                      ),
                      BeakProgressStep(
                        state: OrderStatus.confirmed,
                        label: 'Confirmed',
                        details: BeakRecordTemplate(
                          textGap: 0,
                          title: BeakValueBinding<BeakRecord>.computed(
                            dependencies: [OrderModel.activities],
                            compute: (state) =>
                                (state.read(OrderModel.activities) ??
                                        const <BeakRecord>[])
                                    .where(
                                      (row) =>
                                          row.asOrderActivity.kind ==
                                          'confirmed',
                                    )
                                    .firstOrNull,
                            display: (value, format) => value == null
                                ? 'Awaiting confirmation'
                                : '${format.time(value.asOrderActivity.occurredAt)} · ${value.asOrderActivity.actor.toLowerCase()}',
                          ),
                          subtitle: [
                            BeakValueBinding<String>.computed(
                              dependencies: [OrderModel.approvalStatus],
                              compute: (row) =>
                                  row.read(OrderModel.approvalStatus) ==
                                      ApprovalStatus.pending
                                  ? 'Awaiting approval'
                                  : 'within budget',
                            ),
                          ],
                        ),
                      ),
                      BeakProgressStep(
                        state: OrderStatus.inKitchen,
                        label: 'In kitchen',
                        details: BeakRecordTemplate(
                          textGap: 0,
                          title: BeakValueBinding.field(
                            OrderModel.kitchenStartedAt.formatted(
                              BeakValueFormat.time,
                            ),
                          ),
                          subtitle: [
                            BeakValueBinding<String>.computed(
                              dependencies: [OrderModel.activities],
                              compute: (row) =>
                                  (row.read(OrderModel.activities) ??
                                          const <BeakRecord>[])
                                      .map((row) => row.asOrderActivity)
                                      .where(
                                        (event) => event.kind == 'startKitchen',
                                      )
                                      .firstOrNull
                                      ?.actor,
                            ),
                          ],
                        ),
                      ),
                      BeakProgressStep(
                        state: OrderStatus.outForDelivery,
                        label: 'Out for delivery',
                        details: BeakRecordTemplate(
                          textGap: 0,
                          title: _scheduledTime(OrderModel.dispatchedAt, -20),
                          subtitle: [
                            BeakValueBinding.field(OrderModel.driverName),
                          ],
                        ),
                      ),
                      BeakProgressStep(
                        state: OrderStatus.delivered,
                        label: 'Delivered',
                        details: BeakRecordTemplate(
                          textGap: 0,
                          title: _scheduledTime(OrderModel.deliveredAt, 10),
                          subtitle: [
                            BeakValueBinding.field(OrderModel.handover),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              BeakCard(
                title: 'Items',
                headerTrailing: BeakValueBinding<String>.computed(
                  dependencies: [OrderModel.items],
                  compute: (state) =>
                      '${state.read(OrderModel.items)?.length ?? 0} dishes · prices incl. VAT',
                ),
                children: [orderItems(compact: true), _detailItemsFooter()],
              ),
              orderDeliveryCard(),
              orderActivityCard(),
            ],
          ),
          BeakTab(
            title: 'Items',
            badge: BeakValueBinding<int>.computed(
              dependencies: [OrderModel.items],
              compute: (row) => row.read(OrderModel.items)?.length ?? 0,
            ),
            children: [
              BeakCard(
                title: 'Dishes and options',
                children: [
                  orderItems(allowEditing: false, compact: true),
                  BeakColumns(
                    minColumnWidth: 220,
                    children: [
                      orderAllergyNotice(),
                      orderMoneySummary(title: null, compact: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
          BeakTab(
            title: 'Delivery',
            children: [
              BeakCard(
                title: 'Dispatch and capacity',
                children: [
                  BeakFormTemplate(
                    template: BeakRecordTemplate(
                      title: BeakValueBinding.field(OrderModel.location.name),
                      subtitle: [
                        orderAddress(saved: true),
                        BeakValueBinding.field(OrderModel.handover),
                      ],
                    ),
                  ),
                  BeakFormCapacity(
                    label: 'Delivery slot',
                    value: (state) => state.asOrder.slot?.reservedOrders,
                    max: (state) => state.asOrder.slot?.capacity,
                    dependencies: [
                      OrderModel.slot.reservedOrders,
                      OrderModel.slot.capacity,
                    ],
                    warningText: 'This delivery slot is almost full.',
                  ),
                  OrderModel.routeCode.inputText(
                    label: 'Route',
                    readOnly: true,
                  ),
                  OrderModel.driverName.inputText(
                    label: 'Driver',
                    readOnly: true,
                  ),
                  OrderModel.dispatchedAt.input(readOnly: true),
                  OrderModel.deliveredAt.input(readOnly: true),
                ],
              ),
            ],
          ),
          BeakTab(
            title: 'Payment & invoice',
            children: [
              BeakCard(
                title: 'Payment',
                children: [
                  OrderModel.paymentStatus.input(readOnly: true),
                  OrderModel.approvalStatus.input(readOnly: true),
                  OrderModel.paymentMethod.inputCombobox(
                    label: 'Saved payment method',
                  ),
                  OrderModel.invoice.inputCombobox(
                    label: 'Invoice',
                    enabledIf: (_) => false,
                  ),
                  OrderModel.purchaseOrder.inputText(label: 'Purchase order'),
                  OrderModel.invoiceText.inputText(label: 'Invoice note'),
                ],
              ),
              BeakCard(
                title: 'Vouchers and discounts',
                children: [
                  OrderModel.voucher.inputCombobox(label: 'Voucher'),
                  OrderModel.manualDiscountCents.inputCurrency(
                    label: 'Manual discount',
                    minorUnits: true,
                  ),
                  orderMoneySummary(title: null, compact: true),
                ],
              ),
            ],
          ),
          BeakTab(
            title: 'Activity',
            badge: BeakValueBinding<int>.computed(
              dependencies: [OrderModel.activities],
              compute: (row) => row.read(OrderModel.activities)?.length ?? 0,
            ),
            children: [orderActivityCard()],
          ),
        ],
      ),
    ],
  ),
);

/// Shared delivery layout respects the model's stage-based edit permissions.
BeakCard orderDeliveryCard() => BeakCard(
  title: 'Delivery',
  headerTrailing: BeakValueBinding<String>.computed(
    dependencies: [OrderModel.customer.firstName, OrderModel.profile.name],
    compute: (row) =>
        "From ${row.read(OrderModel.customer.firstName) ?? 'the customer'}'s ${row.read(OrderModel.profile.name) ?? 'delivery'} profile",
    maxLines: 1,
  ),
  children: [
    BeakModeLayout(
      read: BeakFormLayout(
        children: [
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Date',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.deliveryDate,
                display: (value, format) => value is BeakDate
                    ? format.calendarDate(value, pattern: 'EEE d MMM yyyy')
                    : format.emptyValue,
                description: (state) =>
                    state.asOrder.deliveryDate == const FoodioClock().today
                    ? 'Today'
                    : 'Scheduled delivery',
              ),
              BeakCalculated(
                label: 'Slot',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.slot?.name,
                dependencies: [
                  OrderModel.slot.name,
                  OrderModel.slot.startMinute,
                  OrderModel.slot.reservedOrders,
                  OrderModel.slot.capacity,
                ],
                description: _slotDescription,
              ),
            ],
          ),
          BeakCalculated(
            label: 'Delivery method',
            presentation: BeakCalculatedPresentation.detail,
            value: (state) => _deliveryMethod(state.asOrder.deliveryMethod),
            description: (state) => state.asOrder.handover?.isNotEmpty == true
                ? state.asOrder.handover!
                : 'Delivery instructions follow the selected location.',
          ),
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Location',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) =>
                    [state.asOrder.location?.name, state.asOrder.handover]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' — '),
                dependencies: [
                  OrderModel.location.name,
                  OrderModel.location.street,
                  OrderModel.location.postalCode,
                  OrderModel.location.city,
                ],
                description: (state) =>
                    '${state.asOrder.street ?? ''}, ${state.asOrder.postalCode ?? ''} ${state.asOrder.city ?? ''}',
              ),
              BeakCalculated(
                label: 'Contact phone on arrival',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) => state.asOrder.contactPhone,
                description: (_) => 'Used by the driver on arrival.',
              ),
            ],
          ),
          BeakColumns(
            children: [
              BeakCalculated(
                label: 'Delivery note',
                presentation: BeakCalculatedPresentation.detail,
                value: (state) =>
                    state.asOrder.deliveryNote?.trim().isEmpty == true
                    ? null
                    : state.asOrder.deliveryNote,
                description: (state) =>
                    state.asOrder.deliveryNote?.trim().isNotEmpty == true
                    ? 'Visible to the driver'
                    : 'Nothing for the driver',
              ),
              _shippingDetails(BeakCalculatedPresentation.detail),
            ],
          ),
        ],
      ),
      edit: BeakFormLayout(
        children: [
          BeakColumns(
            children: [
              BeakModeLayout(
                read: const BeakFormLayout(children: []),
                edit: BeakFormLayout(
                  children: [
                    BeakCalculated(
                      label: 'Date',
                      presentation: BeakCalculatedPresentation.field,
                      icon: OiIcons.calendar,
                      visibleIf: (state) => !_identityEditable(state),
                      value: (state) => state.asOrder.deliveryDate,
                      display: (value, format) => value is BeakDate
                          ? format.calendarDate(
                              value,
                              pattern: 'EEE d MMM yyyy',
                            )
                          : format.emptyValue,
                      description: (_) =>
                          "The kitchen has started, so the day can't change.",
                    ),
                    OrderModel.deliveryDate.input(
                      label: 'Date',
                      visibleIf: _identityEditable,
                    ),
                  ],
                ),
              ),
              BeakFormLayout(
                spacing: 6,
                children: [
                  OrderModel.slot.inputCombobox(
                    label: 'Slot',
                    validate: const [BeakRequired()],
                    template: BeakRecordTemplate.fields(
                      title: DeliverySlotModel.name,
                    ),
                    options: (state) => DeliverySlotModel.options(
                      filter: BeakAndFilter([
                        DeliverySlotModel.date.eq(
                          state.asOrder.deliveryDate ??
                              const FoodioClock().today,
                        ),
                        DeliverySlotModel.active.eq(true),
                      ]),
                    ),
                  ),
                  BeakCalculated(
                    value: _slotEditDescription,
                    dependencies: [
                      OrderModel.slot.startMinute,
                      OrderModel.slot.reservedOrders,
                      OrderModel.slot.capacity,
                    ],
                    valueStyle: const TextStyle(fontSize: 12, height: 4 / 3),
                  ),
                ],
              ),
            ],
          ),
          OrderModel.deliveryMethod.inputRadio(
            label: 'Delivery method',
            groupLabelAsField: true,
            cards: true,
            minCardWidth: 180,
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            options: (_) => const [
              BeakInputOption(
                'office',
                'Office delivery',
                description: 'Reception, 3rd floor',
              ),
              BeakInputOption(
                'fridge',
                'Smart fridge',
                description: 'Simmering location only',
              ),
              BeakInputOption(
                'pickup',
                'Pickup at kitchen',
                description: 'Obere Donaustraße 14',
              ),
            ],
          ),
          BeakColumns(
            children: [
              BeakRelationInput(
                field: OrderModel.location,
                label: 'Location',
                validate: const [BeakRequired()],
                descriptionBuilder: (state) =>
                    '${state.asOrder.location?.street ?? ''}, ${state.asOrder.location?.postalCode ?? ''} ${state.asOrder.location?.city ?? ''}',
                template: BeakRecordTemplate(
                  title: BeakValueBinding<String>.computed(
                    dependencies: [
                      DeliveryLocationModel.name,
                      DeliveryLocationModel.handover,
                    ],
                    compute: (row) =>
                        [
                              row.read(DeliveryLocationModel.name),
                              row.read(DeliveryLocationModel.handover),
                            ]
                            .whereType<String>()
                            .where((part) => part.isNotEmpty)
                            .join(' — '),
                  ),
                ),
              ),
              OrderModel.contactPhone.inputText(
                label: 'Contact phone on arrival',
              ),
            ],
          ),
          BeakColumns(
            children: [
              OrderModel.deliveryNote.inputText(
                label: 'Delivery note (optional)',
                multilineContentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                maxLines: 2,
                showCounter: false,
                placeholder: 'Anything the driver should know',
              ),
              _shippingDetails(BeakCalculatedPresentation.field),
            ],
          ),
        ],
      ),
    ),
  ],
);

String _deliveryMethod(String? method) => switch (method) {
  'office' => 'Office delivery',
  'fridge' => 'Smart fridge',
  'pickup' => 'Pickup at kitchen',
  _ => '—',
};

String _slotDescription(BeakFormReader state) {
  final slot = state.asOrder.slot;
  if (slot == null) return 'Choose a delivery slot';
  final expected = (slot.startMinute + 10).clamp(0, 1439);
  return 'Expected at ${(expected ~/ 60).toString().padLeft(2, '0')}:${(expected % 60).toString().padLeft(2, '0')} · slot ${slot.reservedOrders} of ${slot.capacity} booked';
}

String _slotEditDescription(BeakFormReader state) {
  final slot = state.asOrder.slot;
  if (slot == null) return 'Choose a delivery slot';
  final before = OrderModel.slot.name.readFrom(state.draft.initialRecord);
  final expected = (slot.startMinute + 10).clamp(0, 1439);
  final time =
      '${(expected ~/ 60).toString().padLeft(2, '0')}:${(expected % 60).toString().padLeft(2, '0')}';
  return before != null && before != slot.name
      ? 'Moved from $before · expected at $time'
      : 'Expected at $time · slot ${slot.reservedOrders} of ${slot.capacity} booked';
}

BeakCalculated _shippingDetails(
  BeakCalculatedPresentation presentation,
) => BeakCalculated(
  label: 'Shipping',
  presentation: presentation,
  icon: presentation == BeakCalculatedPresentation.field ? OiIcons.truck : null,
  value: (state) => 'Cooled van · Route ${state.asOrder.routeCode ?? '—'}',
  description: (state) => presentation == BeakCalculatedPresentation.field
      ? 'Set by the location · driver ${state.asOrder.driverName ?? 'not assigned'}'
      : 'Driver ${state.asOrder.driverName ?? 'not assigned'}',
);

bool _identityEditable(BeakFormReader state) => !{
  OrderStatus.inKitchen,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
  OrderStatus.cancelled,
}.contains(state.asOrder.status);

/// Immutable activity history is loaded automatically through its relationship.
BeakCard orderActivityCard() => BeakCard(
  title: 'Activity',
  headerTrailing: BeakValueBinding<String>.computed(
    dependencies: const [],
    compute: (_) => 'Today · newest first',
  ),
  children: [
    BeakFormTimeline(
      field: OrderModel.activities,
      compact: true,
      inlineTime: true,
      actor: BeakValueBinding<String>.computed(
        dependencies: [OrderActivityModel.actor],
        compute: (row) => row.read(OrderActivityModel.actor) == 'Automatic'
            ? null
            : row.read(OrderActivityModel.actor),
      ),
      columns: 2,
      title: OrderActivityModel.title,
      time: OrderActivityModel.occurredAt,
      description: OrderActivityModel.description,
    ),
  ],
);

IconData _orderIcon(BeakDraftReader _) => OiIcons.shoppingBag;

BeakRecordTemplate _customerDetails() => BeakRecordTemplate(
  title: BeakValueBinding.field(
    OrderModel.customer.name,
    textStyle: const TextStyle(fontWeight: FontWeight.w500),
  ),
  avatar: true,
  avatarSize: OiAvatarSize.md,
  avatarPalette: identityPalette,
  identityGap: 12,
  textGap: 0,
  detailsGap: 4,
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
  identityGap: 12,
  textGap: 0,
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

BeakCard _customerProfileCard() => BeakCard(
  title: 'Customer and profile',
  children: [
    BeakFormTemplate(template: _customerDetails()),
    BeakModeLayout(
      read: BeakFormLayout(
        children: [
          BeakFormLayout(
            spacing: 6,
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
            visibleIf: (state) => !_identityEditable(state),
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
            visibleIf: _identityEditable,
            template: customerIdentity(),
          ),
          OrderModel.profile.inputCombobox(
            label: 'Profile',
            enabledIf: _identityEditable,
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
        spacing: 2,
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
              textGap: 0,
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
      spacing: 0,
      children: [
        BeakFormCapacity(
          label: 'Budget this month',
          valueStyle: const TextStyle(fontSize: 14, height: 10 / 7),
          height: 8,
          gap: 6,
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
          read: BeakFormLayout(children: [_approvalNotice(editing: false)]),
          edit: BeakFormLayout(children: [_approvalNotice(editing: true)]),
        ),
      ],
    ),
  ],
);

BeakCalculated _approvalNotice({required bool editing}) => BeakCalculated(
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
  spacing: 6,
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

BeakColumns _detailItemsFooter() => BeakColumns(
  minColumnWidth: 220,
  gap: 24,
  columnWidths: const [null, 248],
  padding: const EdgeInsetsDirectional.only(end: 44),
  children: [
    BeakFormLayout(
      spacing: 12,
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
      gap: 2,
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
          dividerSpacing: 6,
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

BeakValueBinding<Object> _scheduledTime(
  BeakScalarField<DateTime> actual,
  int offset,
) => BeakValueBinding<Object>.computed(
  dependencies: [actual, OrderModel.slot.startMinute],
  compute: (row) {
    final stored = row.read(actual);
    if (stored != null) return stored;
    final start = row.read(OrderModel.slot.startMinute);
    if (start == null) return null;
    final minute = (start + offset).clamp(0, 1439);
    return BeakTime(minute ~/ 60, minute % 60);
  },
  display: (value, format) => value == null
      ? format.emptyValue
      : '${value is BeakTime ? 'Expected ' : ''}${format.format(value, BeakValueFormat.time)}',
);

BeakFormNotice _changeNotice({required bool editing}) => BeakFormNotice(
  tone: BeakColor.muted,
  visibleIf: (state) => !{
    OrderStatus.delivered,
    OrderStatus.cancelled,
    OrderStatus.outForDelivery,
  }.contains(state.asOrder.status),
  inline: true,
  caption: editing
      ? (_) =>
            '${630 - (const FoodioClock().local.hour * 60 + const FoodioClock().local.minute)} minutes left'
      : null,
  icon: editing ? OiIcons.info : OiIcons.clock,
  title: editing
      ? 'The kitchen and the driver see changes immediately.'
      : 'Open for changes until 10:30',
  message: (_) => editing
      ? 'Items can change until 10:30.'
      : '${630 - (const FoodioClock().local.hour * 60 + const FoodioClock().local.minute)} minutes left. The kitchen and the driver see every change immediately.',
);
