import 'package:beak/panel.dart';

import '../../../models/models.dart';
import '../dashboard/order_overview.dart';

/// Saved-view filter definitions shared by the order list and its filter drawer.
final class OrderListFilters {
  /// Creates the complete filter set used in order-list definitions.
  const OrderListFilters({
    required this.date,
    required this.status,
    required this.organization,
    required this.slot,
    required this.payment,
  });

  /// Delivery date with common saved-view presets.
  final BeakSemanticRangeFilter date;

  /// Lifecycle and attention status facets.
  final BeakChoiceFilter status;

  /// Organization names used by business customers.
  final BeakChoiceFilter organization;

  /// Delivery-slot start times.
  final BeakChoiceFilter slot;

  /// Payment modes grouped into customer-facing methods.
  final BeakChoiceFilter payment;
}

/// Domain-specific filters for common order search and saved views.
OrderListFilters orderListFilters() {
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
  return OrderListFilters(
    date: date,
    status: status,
    organization: organization,
    slot: slot,
    payment: payment,
  );
}
