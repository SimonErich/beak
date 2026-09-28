import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart'
    show FontWeight, TextAlign, TextOverflow, TextStyle;

import '../../../models/models.dart';
import '../../../theme/gabel_theme.dart';
import '../dashboard/order_overview.dart';
import '../presentations/order_presentations.dart';

/// Columns and cell presentations for the order list's default table.
List<BeakTableColumn> orderTableColumns() {
  return [
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
        subtitle: [orderPlacementSummary()],
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
        subtitle: [orderOrganizationSummary()],
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
        title: orderDeliveryTitle(),
        subtitle: [orderDeliverySummary()],
      ),
    ),
    BeakTableColumn(
      key: 'items',
      label: 'Items',
      textAlign: TextAlign.end,
      width: 57,
      sortBy: OrderModel.itemCount,
      template: BeakRecordTemplate(
        title: BeakValueBinding.field(
          OrderModel.itemCount,
          textStyle: gabelNumericBodyStyle,
        ),
      ),
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
}

/// Placement source and time shown beneath the order reference.
BeakValueBinding<String>
orderPlacementSummary() => BeakValueBinding<String>.computed(
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

/// Organization name shown under the customer identity.
BeakValueBinding<String> orderOrganizationSummary({bool attention = false}) =>
    BeakValueBinding<String>.computed(
      dependencies: [OrderModel.organizationName, OrderModel.nextAction],
      compute: (row) {
        final company = row.read(OrderModel.organizationName);
        if (company != null && company.isNotEmpty) return company;
        return 'Private';
      },
    );

/// Delivery window label for standard and attention queues.
BeakValueBinding<String>
orderDeliveryTitle() => BeakValueBinding<String>.computed(
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

/// Delivery route detail shown under the delivery window.
BeakValueBinding<String> orderDeliverySummary({bool attention = false}) =>
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
