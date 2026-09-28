import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../../../models/models.dart';
import 'order_identity_tokens.dart';

/// Prioritized order, payment, delivery, and approval status badge.
BeakValueBinding<String> orderStatus() => BeakValueBinding<String>.computed(
  dependencies: [
    OrderModel.status,
    OrderModel.paymentStatus,
    OrderModel.approvalStatus,
    OrderModel.nextAction,
  ],
  badge: true,
  badgeDot: true,
  badgeDotFor: (row) =>
      row.read(OrderModel.paymentStatus) != PaymentStatus.failed &&
      row.read(OrderModel.nextAction) != 'reschedule',
  iconFor: (row) =>
      row.read(OrderModel.paymentStatus) == PaymentStatus.failed ||
          row.read(OrderModel.nextAction) == 'reschedule'
      ? OiIcons.circleAlert
      : null,
  compute: (row) {
    if (row.read(OrderModel.status) == OrderStatus.cancelled) {
      return 'Cancelled';
    }
    if (row.read(OrderModel.approvalStatus) == ApprovalStatus.pending) {
      return 'Approval needed';
    }
    if (row.read(OrderModel.paymentStatus) == PaymentStatus.failed) {
      return 'Payment failed';
    }
    if (row.read(OrderModel.paymentStatus) == PaymentStatus.pending) {
      return 'Pending payment';
    }
    if (row.read(OrderModel.nextAction) == 'reschedule') {
      return 'Delivery failed';
    }
    if (row.read(OrderModel.nextAction) == 'reviewChange') {
      return 'Change requested';
    }
    return switch (row.read(OrderModel.status)) {
      OrderStatus.draft => 'Draft',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.inKitchen => 'In kitchen',
      OrderStatus.outForDelivery => 'Out for delivery',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.onHold => 'On hold',
      null => '—',
    };
  },
  tone: (row) {
    if (row.read(OrderModel.status) == OrderStatus.cancelled) {
      return BeakColor.muted;
    }
    if (row.read(OrderModel.paymentStatus) == PaymentStatus.failed ||
        row.read(OrderModel.nextAction) == 'reschedule') {
      return BeakColor.error;
    }
    if (row.read(OrderModel.nextAction) == 'reviewChange') {
      return BeakColor.warning;
    }
    if (row.read(OrderModel.approvalStatus) == ApprovalStatus.pending ||
        row.read(OrderModel.paymentStatus) == PaymentStatus.pending) {
      return BeakColor.warning;
    }
    return switch (row.read(OrderModel.status)) {
      OrderStatus.confirmed => BeakColor.primary,
      OrderStatus.outForDelivery => BeakColor.info,
      OrderStatus.inKitchen => BeakColor.info,
      OrderStatus.delivered => BeakColor.success,
      OrderStatus.onHold => BeakColor.warning,
      _ => BeakColor.muted,
    };
  },
);

/// Allergen warnings are advisory unless the customer requests strict handling.
BeakFormNotice orderAllergyNotice({bool plain = false}) => BeakFormNotice(
  plain: plain,
  title: plain ? null : 'Customer allergen alert',
  tone: BeakColor.warning,
  dependencies: [OrderModel.customer.allergens, OrderModel.customer.name],
  visibleIf: (state) => (state.asOrder.customer?.allergens ?? '').isNotEmpty,
  message: (state) =>
      '${plain ? '${state.asOrder.customer?.firstName ?? 'Customer'} has an allergen alert for ' : ''}${(state.asOrder.customer?.allergens ?? '').split(',').map((code) => allergenLabel(code.trim())).join(', ')}. '
      '${state.asOrder.allergenNote ?? (plain ? 'Check the dishes for her own portion.' : 'Check each dish and preparation note before preparing this order.')}',
);
