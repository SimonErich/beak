import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart'
    show EdgeInsets, FontWeight, TextAlign, TextOverflow, TextStyle;

import '../../models/models.dart';
import 'order_overview.dart';
import 'order_presentations.dart';

/// Every list, filter, counter and chart shares this typed population.
BeakTableScreen orderList() {
  final date = OrderModel.deliveryDate.dateRangeFilter(
    label: 'Delivery date',
    inline: true,
    presets: const [
      BeakRangePreset(label: 'Today', lower: foodioToday, upper: foodioToday),
      BeakRangePreset(
        label: 'Tomorrow',
        lower: BeakDate(2026, 9, 29),
        upper: BeakDate(2026, 9, 29),
      ),
      BeakRangePreset(
        label: 'This week',
        lower: foodioToday,
        upper: BeakDate(2026, 10, 4),
      ),
    ],
  );
  final status = BeakChoiceFilter(
    field: OrderModel.status,
    label: 'Status',
    showCounts: true,
    columns: 2,
    options: [
      for (final entry in [
        (OrderStatus.confirmed, 'Confirmed'),
        (OrderStatus.inKitchen, 'In kitchen'),
        (OrderStatus.outForDelivery, 'Out for delivery'),
        (OrderStatus.delivered, 'Delivered'),
      ])
        BeakFilterChoice(
          key: entry.$1.name,
          label: entry.$2,
          filter: OrderModel.status.eq(entry.$1),
        ),
      BeakFilterChoice(
        key: 'attention',
        label: 'Needs attention',
        filter: OrderModel.needsAttention.eq(true),
      ),
      BeakFilterChoice(
        key: 'cancelled',
        label: 'Cancelled',
        filter: OrderModel.status.eq(OrderStatus.cancelled),
      ),
    ],
  );
  final organization = BeakChoiceFilter(
    field: OrderModel.organizationName,
    label: 'Organization',
    presentation: BeakChoiceFilterPresentation.combobox,
    addItemLabel: 'Add organization',
    options: [
      for (final name in [
        'Nordlicht Energie GmbH',
        'Kessler Logistik GmbH',
        'Donaupark Kliniken',
        'Halden & Co.',
      ])
        BeakFilterChoice(
          key: name,
          label: name,
          filter: OrderModel.organization.name.eq(name),
        ),
    ],
  );
  final slot = BeakChoiceFilter(
    field: OrderModel.slot.name,
    label: 'Delivery slot',
    presentation: BeakChoiceFilterPresentation.chips,
    options: [
      for (final entry in [
        (480, '08:00–08:30'),
        (660, '11:00–11:30'),
        (690, '11:30–12:00'),
        (720, '12:00–12:30'),
        (750, '12:30–13:00'),
      ])
        BeakFilterChoice(
          key: entry.$1.toString(),
          label: entry.$2,
          filter: OrderModel.slot.startMinute.eq(entry.$1),
        ),
    ],
  );
  final payment = BeakChoiceFilter(
    field: OrderModel.paymentMode,
    label: 'Payment method',
    columns: 2,
    options: [
      BeakFilterChoice(
        key: 'invoice',
        label: 'Company invoice',
        filter: BeakOrFilter([
          OrderModel.paymentMode.eq('monthlyInvoice'),
          OrderModel.paymentMode.eq('weeklyInvoice'),
          OrderModel.paymentMode.eq('perOrderInvoice'),
        ]),
      ),
      for (final entry in [
        ('sepa', 'SEPA Direct Debit'),
        ('card', 'Credit card'),
        ('paypal', 'PayPal'),
        ('subsidyCard', 'Subsidy + card'),
      ])
        BeakFilterChoice(
          key: entry.$1,
          label: entry.$2,
          filter: OrderModel.paymentMode.eq(entry.$1),
        ),
    ],
  );
  final columns = [
    BeakTableColumn(
      key: 'order',
      label: 'Order',
      sortBy: OrderModel.number,
      width: 120,
      template: BeakRecordTemplate(
        textGap: 0,
        title: BeakValueBinding.field(
          OrderModel.reference,
          monospace: true,
          color: BeakColor.primary,
        ),
        subtitle: [_placementSummary()],
      ),
    ),
    BeakTableColumn(
      key: 'customer',
      label: 'Customer',
      width: 234,
      template: BeakRecordTemplate(
        textGap: 0,
        identityGap: 12,
        title: BeakValueBinding.field(
          OrderModel.customerName,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: [_organizationSummary()],
        avatar: true,
        avatarTone: BeakValueBinding.computed(
          dependencies: [OrderModel.organizationName],
          compute: (row) {
            final organization = row.read(OrderModel.organizationName);
            if (organization == null || organization.isEmpty) {
              return identityPalette[2];
            }
            return organization == 'Nordlicht Energie GmbH'
                ? identityPalette[0]
                : identityPalette[1];
          },
        ),
      ),
    ),
    BeakTableColumn(
      key: 'delivery',
      label: 'Delivery',
      width: 156,
      template: BeakRecordTemplate(
        textGap: 0,
        title: _deliveryTitle(),
        subtitle: [_deliverySummary()],
      ),
    ),
    BeakTableColumn(
      key: 'items',
      label: 'Items',
      textAlign: TextAlign.end,
      width: 56,
      sortBy: OrderModel.itemCount,
      template: BeakRecordTemplate.fields(title: OrderModel.itemCount),
    ),
    BeakTableColumn(
      key: 'total',
      label: 'Total',
      textAlign: TextAlign.end,
      sortBy: OrderModel.grossCents,
      width: 82,
      template: BeakRecordTemplate(
        title: BeakValueBinding.field(
          OrderModel.grossCents.currency(minorUnits: true),
        ),
      ),
    ),
    BeakTableColumn(
      key: 'payment',
      label: 'Payment',
      width: 140,
      template: BeakRecordTemplate(
        textGap: 0,
        title: BeakValueBinding<String>.computed(
          dependencies: [OrderModel.paymentMode],
          textOverflow: TextOverflow.visible,
          compute: (row) => _paymentTitle(row.read(OrderModel.paymentMode)),
        ),
        subtitle: [_paymentSummary()],
      ),
    ),
    BeakTableColumn(
      key: 'status',
      label: 'Status',
      width: 164,
      template: BeakRecordTemplate(title: orderStatus()),
    ),
  ];
  return BeakTableScreen(
    query: const OrderModel()
        .query()
        .orderBy(OrderModel.number.column, descending: true)
        .paginate(perPage: 15),
    definition: BeakListDefinition(
      initialPreset: 'today',
      filterSheetWidth: 480,
      recordNoun: 'orders',
      advancedFilterColumns: 2,
      advancedFilterDescription:
          'Voucher used, order value, allergy notes, created by',
      fitTableToRows: true,
      scrollMode: BeakListScrollMode.page,
      floatingBulkActions: true,
      filterDescription:
          'Combine filters, then save them as a view for your team.',
      title: 'Orders',
      searchPlaceholder: 'Search by order, customer, company or phone',
      subtitleBuilder: (counts) =>
          '${counts['today'] ?? '—'} orders for today · ${counts['attention'] ?? '—'} need attention · updated 09:42',
      createLabel: 'New order',
      export: BeakListExport(
        fileName: 'orders.csv',
        fields: [
          OrderModel.reference,
          OrderModel.customerName,
          OrderModel.organizationName,
          OrderModel.deliveryDate,
          OrderModel.itemCount,
          OrderModel.grossCents.currency(minorUnits: true),
          OrderModel.paymentStatus,
          OrderModel.status,
        ],
      ),
      quickFilters: [date, status, organization, slot, payment],
      quickFilterLabels: {slot: 'Slot', payment: 'Payment'},
      rowActions: [
        const BeakActionPresentation(
          key: 'view',
          label: 'View order',
          icon: OiIcons.eye,
          group: 'record',
        ),
        const BeakActionPresentation(
          key: 'edit',
          label: 'Edit delivery address',
          icon: OiIcons.mapPin,
          group: 'record',
        ),
        BeakActionPresentation(
          key: 'call-customer',
          icon: OiIcons.phone,
          group: 'record',
          labelValue: BeakValueBinding<String>.computed(
            dependencies: [OrderModel.customerName],
            compute: (row) =>
                'Call ${row.read(OrderModel.customerName) ?? 'customer'}',
          ),
        ),
        const BeakActionPresentation.model(
          'addNote',
          label: 'Add internal note',
          icon: OiIcons.messageSquare,
          group: 'record',
        ),
        const BeakActionPresentation.model(
          'cancel',
          label: 'Cancel order',
          icon: OiIcons.circleX,
          destructive: true,
          group: 'destructive',
        ),
      ],
      bulkActions: [
        const BeakActionPresentation.model(
          'sendPaymentLink',
          label: 'Send payment links',
          icon: OiIcons.send,
        ),
        const BeakActionPresentation(key: 'export', icon: OiIcons.download),
        BeakActionPresentation.model(
          'cancel',
          icon: OiIcons.circleX,
          destructive: true,
          selectionLabel: (count) => 'Cancel $count orders',
        ),
      ],
      savedViews: BeakSavedViewStore.model(
        model: const SavedViewModel(),
        name: SavedViewModel.name,
        resource: SavedViewModel.resource,
        state: SavedViewModel.state,
      ),
      header: orderOverview(),
      collapsedHeader: orderCompactOverview(),
      showHeaderToggle: true,
      presets: [
        BeakQueryPreset(
          key: 'today',
          label: 'Today',
          defaults: {
            date: BeakAndFilter([
              OrderModel.deliveryDate.gte(foodioToday),
              OrderModel.deliveryDate.lte(foodioToday),
            ]),
          },
        ),
        BeakQueryPreset(
          key: 'attention',
          label: 'Needs attention',
          rowHeight: 64,
          countColor: BeakColor.error,
          filter: OrderModel.needsAttention.eq(true),
          quickFilters: [status, date, organization, slot, payment],
          defaults: {
            status: OrderModel.needsAttention.eq(true),
            date: BeakAndFilter([
              OrderModel.deliveryDate.gte(foodioToday),
              OrderModel.deliveryDate.lte(const BeakDate(2026, 9, 29)),
            ]),
          },
          columns: [
            for (final column in columns.where(
              (column) =>
                  {'order', 'customer', 'delivery'}.contains(column.key),
            ))
              BeakTableColumn(
                key: column.key,
                label: column.label,
                template: column.key == 'customer'
                    ? BeakRecordTemplate(
                        textGap: 0,
                        title: BeakValueBinding.field(
                          OrderModel.customerName,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: [_organizationSummary(attention: true)],
                      )
                    : column.key == 'delivery'
                    ? BeakRecordTemplate(
                        textGap: 0,
                        title: _deliveryTitle(),
                        subtitle: [_deliverySummary(attention: true)],
                      )
                    : column.template!,
                sortBy: column.sortBy,
                width: switch (column.key) {
                  'order' => 112,
                  'customer' => 168,
                  _ => 132,
                },
              ),
            BeakTableColumn(
              key: 'issue',
              label: 'Problem',
              width: 188,
              template: BeakRecordTemplate(
                title: BeakValueBinding.field(
                  OrderModel.attentionReason,
                  maxLines: 2,
                ),
              ),
            ),
            BeakTableColumn.action(
              key: 'next_step',
              label: 'Next step',
              width: 188,
              selector: BeakValueBinding.field(OrderModel.nextAction),
              choices: const {
                'sendPaymentLink': BeakActionPresentation.model(
                  'sendPaymentLink',
                ),
                'retryPayment': BeakActionPresentation.model('retryPayment'),
                'requestApproval': BeakActionPresentation.model(
                  'requestApproval',
                  label: 'Ask for approval',
                ),
                'acknowledgeAllergy': BeakActionPresentation.model(
                  'acknowledgeAllergy',
                  label: 'Confirm with kitchen',
                ),
                'reschedule': BeakActionPresentation.model(
                  'reschedule',
                  label: 'Schedule redelivery',
                ),
                'reviewChange': BeakActionPresentation.model(
                  'resolveChange',
                  label: 'Review change',
                ),
                'editAddress': BeakActionPresentation(
                  key: 'edit',
                  label: 'Edit address',
                ),
              },
              fallback: const BeakActionPresentation(
                key: 'view',
                label: 'Review order',
              ),
            ),
            BeakTableColumn(
              key: 'status',
              label: 'Status',
              width: 164,
              template: BeakRecordTemplate(title: orderStatus()),
            ),
          ],
        ),
        BeakQueryPreset(
          key: 'scheduled',
          label: 'Scheduled',
          filter: OrderModel.awaitingRelease.eq(true),
        ),
        BeakQueryPreset(
          key: 'drafts',
          label: 'Drafts',
          filter: OrderModel.status.eq(OrderStatus.draft),
        ),
        const BeakQueryPreset(key: 'all', label: 'All orders'),
      ],
      columns: columns,
      filters: [
        date,
        status,
        BeakChoiceFilter(
          field: OrderModel.profile.kind,
          label: 'Customer',
          presentation: BeakChoiceFilterPresentation.radio,
          options: [
            BeakFilterChoice(
              key: 'company',
              label: 'Company profiles',
              filter: OrderModel.profile.kind.eq('company'),
            ),
            BeakFilterChoice(
              key: 'private',
              label: 'Private profiles',
              filter: OrderModel.profile.kind.eq('private'),
            ),
          ],
        ),
        organization,
        slot,
        payment,
        BeakChoiceFilter(
          field: OrderModel.voucherCode,
          label: 'Voucher used',
          advanced: true,
          presentation: BeakChoiceFilterPresentation.select,
          allLabel: 'Any or none',
          options: [
            BeakFilterChoice(
              key: 'any',
              label: 'With a voucher',
              filter: BeakAndFilter([
                OrderModel.voucherCode.notEq(null),
                OrderModel.voucherCode.notEq(''),
              ]),
            ),
            for (final code in ['LUNCH15', 'WELCOME10'])
              BeakFilterChoice(
                key: code,
                label: code,
                filter: OrderModel.voucherCode.eq(code),
              ),
          ],
        ),
        BeakChoiceFilter(
          field: OrderModel.createdBy,
          label: 'Created by',
          advanced: true,
          presentation: BeakChoiceFilterPresentation.select,
          allLabel: 'Anyone',
          options: [
            BeakFilterChoice(
              key: 'customers',
              label: 'Customers (webshop and app)',
              filter: BeakOrFilter([
                OrderModel.source.eq('Webshop'),
                OrderModel.source.eq('App'),
              ]),
            ),
            BeakFilterChoice(
              key: 'staff',
              label: 'Staff (admin)',
              filter: OrderModel.source.eq('Admin'),
            ),
            BeakFilterChoice(
              key: 'marie',
              label: 'Marie Novak',
              filter: OrderModel.createdBy.eq('Marie Novak'),
            ),
          ],
        ),
        OrderModel.grossCents
            .currency(minorUnits: true)
            .numberRangeFilter(
              advanced: true,
              showMaximum: false,
              minimumLabel: 'Order value from (optional)',
              placeholder: 'e.g. 40.00',
            ),
        BeakChoiceFilter(
          field: OrderModel.allergenNote,
          label: 'Allergy note',
          showLabel: false,
          advanced: true,
          options: [
            BeakFilterChoice(
              key: 'with-note',
              label: 'Only orders with an allergy note',
              filter: BeakAndFilter([
                OrderModel.allergenNote.notEq(null),
                OrderModel.allergenNote.notEq(''),
              ]),
            ),
          ],
        ),
      ],
    ),
  );
}

BeakValueBinding<String>
_placementSummary() => BeakValueBinding<String>.computed(
  dependencies: [OrderModel.source, OrderModel.placedAt],
  compute: (row) {
    final source = row.read(OrderModel.source) ?? 'Admin';
    final date = row
        .read(OrderModel.placedAt)
        ?.toUtc()
        .add(const Duration(hours: 2));
    if (source == 'Standing order' || date == null) return source;
    final day = date.toIso8601String().substring(0, 10);
    final time = day == foodioToday.toString()
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday -
              1];
    return '$source · $time';
  },
);

BeakValueBinding<String> _organizationSummary({bool attention = false}) =>
    BeakValueBinding<String>.computed(
      dependencies: [OrderModel.organizationName, OrderModel.nextAction],
      compute: (row) {
        final company = row.read(OrderModel.organizationName);
        if (company != null && company.isNotEmpty) return company;
        return 'Private';
      },
    );

BeakValueBinding<String> _deliveryTitle() => BeakValueBinding<String>.computed(
  dependencies: [
    OrderModel.slot.name,
    OrderModel.deliveryDate,
    OrderModel.nextAction,
  ],
  tone: (row) =>
      row.read(OrderModel.nextAction) == 'reschedule' ? BeakColor.muted : null,
  compute: (row) {
    if (row.read(OrderModel.nextAction) == 'reschedule') return 'Not scheduled';
    final slot = row.read(OrderModel.slot.name) ?? 'Not scheduled';
    final date = row.read(OrderModel.deliveryDate);
    if (date == null || date == foodioToday) return slot;
    final weekday = DateTime.parse(date.toString()).weekday;
    return '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1]} $slot';
  },
);

BeakValueBinding<String> _deliverySummary({bool attention = false}) =>
    BeakValueBinding<String>.computed(
      dependencies: [
        OrderModel.routeCode,
        OrderModel.deliveryMethod,
        OrderModel.nextAction,
        OrderModel.attentionReason,
      ],
      tone: (row) =>
          !attention &&
              {
                'editAddress',
                'reviewChange',
              }.contains(row.read(OrderModel.nextAction))
          ? BeakColor.warning
          : null,
      compute: (row) {
        if (!attention) {
          if (row.read(OrderModel.nextAction) == 'editAddress') {
            return 'Address incomplete';
          }
          if (row.read(OrderModel.nextAction) == 'reviewChange') {
            final reason = row.read(OrderModel.attentionReason) ?? '';
            return reason.split(' instead of ').first;
          }
        }
        return switch (row.read(OrderModel.deliveryMethod)) {
          'pickup' => 'Pickup at kitchen',
          _
              when row
                      .read(OrderModel.routeCode)
                      ?.toLowerCase()
                      .startsWith('bike') ??
                  false =>
            'Bike courier',
          _ =>
            attention
                ? 'Cooled van'
                : 'Cooled van · Route ${row.read(OrderModel.routeCode) ?? '—'}',
        };
      },
    );

String? _paymentTitle(String? mode) => switch (mode) {
  'monthlyInvoice' || 'weeklyInvoice' || 'perOrderInvoice' => 'Company invoice',
  'sepa' => 'SEPA Direct Debit',
  'card' => 'Credit card',
  _ => paymentLabels[mode] ?? mode,
};

BeakValueBinding<String> _paymentSummary() => BeakValueBinding<String>.computed(
  dependencies: [
    OrderModel.paymentMode,
    OrderModel.paymentStatus,
    OrderModel.attentionReason,
  ],
  tone: (row) => switch (row.read(OrderModel.paymentStatus)) {
    PaymentStatus.failed => BeakColor.error,
    PaymentStatus.pending => BeakColor.warning,
    _ => null,
  },
  compute: (row) {
    switch (row.read(OrderModel.paymentStatus)) {
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.failed:
        return (row.read(OrderModel.attentionReason) ?? '')
                .toLowerCase()
                .contains('twice')
            ? 'Declined twice'
            : 'Payment failed';
      case PaymentStatus.pending:
        return 'Awaiting card';
      default:
        break;
    }
    return switch (row.read(OrderModel.paymentMode)) {
      'monthlyInvoice' => 'Monthly invoice',
      'weeklyInvoice' => 'Weekly invoice',
      'perOrderInvoice' => 'Invoice per order',
      'subsidyCard' => 'Card paid',
      'sepa' => 'Debit on invoice',
      _ => 'Paid',
    };
  },
);
