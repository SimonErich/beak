import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import '../../../domain/_order_note_input.dart';
import '../../../domain/foodio_clock.dart';
import '../../../domain/order_behavior.dart';
import '../../../theme/gabel_theme.dart';
import 'package:flutter/widgets.dart';

import '../../../models/models.dart';
import '../forms/order_wizard_screen.dart';
import '../presentations/order_presentations.dart';
import '../forms/order_totals.dart';
import 'order_activity_section.dart';
import 'order_customer_section.dart';
import 'order_delivery_section.dart';
import 'order_detail_helpers.dart';

/// The detail and edit routes share one graph and the same section definitions.
BeakFormScreen orderDetailAndEdit() => BeakFormScreen(
  // --8<-- [start:orderDetailOptions]
  roles: const {BeakScreenRole.read, BeakScreenRole.edit},
  submitLabel: 'Save changes',
  submitIcon: OiIcons.check,
  outlinedCancel: true,
  showActionsWhileEditing: false,
  submitAction: OrderActions.amend,
  editLabel: 'Edit order',
  editingLabel: 'Editing',
  prominentEdit: true,
  compactActions: true,
  showChangeBar: true,
  showBack: false,
  pagePadding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
  pageGapInPixels: 24,
  asideFraction: 1 / 3,
  // --8<-- [end:orderDetailOptions]
  // --8<-- [start:orderRecordHeader]
  recordHeader: BeakRecordTemplate(
    icon: const BeakValueBinding<IconData>.computed(
      dependencies: [],
      compute: orderIcon,
    ),
    iconSizeInPixels: 56,
    identityGapInPixels: 16,
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
  // --8<-- [end:orderRecordHeader]
  header: BeakFormLayout(
    spacingInPixels: 24,
    children: [
      // --8<-- [start:orderModeNotice]
      BeakModeLayout(
        read: BeakFormLayout(children: [orderChangeNotice(editing: false)]),
        edit: BeakFormLayout(children: [orderChangeNotice(editing: true)]),
      ),
      // --8<-- [end:orderModeNotice]
      BeakFormMetrics(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        gapInPixels: 4,
        metrics: [
          // --8<-- [start:orderMetricPair]
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
                  : orderDeliveryMethod(state.asOrder.deliveryMethod);
            },
          ),
          // --8<-- [end:orderMetricPair]
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
    spacingInPixels: 24,
    children: [
      orderCustomerProfileCard(),
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
          // --8<-- [start:orderNotesTimeline]
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
              identityGapInPixels: 8,
              textGapInPixels: 0,
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
            action: OrderActions.addNote,
            submitWithForm: OrderActions.amend,
            optionalWithForm: true,
            description: 'Only staff can see internal notes.',
            editDescription: 'Saved with your other changes',
            inlineFooter: true,
            footerMinHeightInPixels: 32,
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
          // --8<-- [end:orderNotesTimeline]
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
            spacingInPixels: 24,
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
                      // --8<-- [start:orderProgressSteps]
                      BeakProgressStep(
                        label: 'Placed',
                        details: BeakRecordTemplate(
                          textGapInPixels: 0,
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
                          textGapInPixels: 0,
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
                      // --8<-- [end:orderProgressSteps]
                      BeakProgressStep(
                        state: OrderStatus.inKitchen,
                        label: 'In kitchen',
                        details: BeakRecordTemplate(
                          textGapInPixels: 0,
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
                                        (event) =>
                                            event.kind ==
                                            OrderActions.startKitchen.name,
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
                          textGapInPixels: 0,
                          title: orderScheduledTime(
                            OrderModel.dispatchedAt,
                            -20,
                          ),
                          subtitle: [
                            BeakValueBinding.field(OrderModel.driverName),
                          ],
                        ),
                      ),
                      BeakProgressStep(
                        state: OrderStatus.delivered,
                        label: 'Delivered',
                        details: BeakRecordTemplate(
                          textGapInPixels: 0,
                          title: orderScheduledTime(OrderModel.deliveredAt, 10),
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
                children: [orderItems(compact: true), orderDetailItemsFooter()],
              ),
              orderDeliveryCard(),
              orderActivityCard(),
            ],
          ),
          // --8<-- [start:orderItemsTab]
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
                    minColumnWidthInPixels: 220,
                    children: [
                      orderAllergyNotice(),
                      orderMoneySummary(title: null, compact: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // --8<-- [end:orderItemsTab]
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
