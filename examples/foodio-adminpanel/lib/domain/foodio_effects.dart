import 'package:beak/migrations.dart';

import '../models/models.dart';
import '_effect_payload.dart';
import 'foodio_clock.dart';
import 'order_behavior.dart';

// --8<-- [start:foodioEffectKindList]
/// The provider effects an order transaction can queue.
enum FoodioEffectKind {
  /// Confirms a placed order to the customer.
  confirmation,

  /// Asks the profile's approver to review an order.
  approval,

  /// Sends the customer a demo payment link.
  paymentLink,

  /// Charges the order to the demo payment provider.
  charge,

  /// Returns collected funds for a cancelled order.
  refund,
}
// --8<-- [end:foodioEffectKindList]

/// Atomically enqueues effects. The worker performs them only after commit.
final class FoodioEffects {
  /// Uses the same clock as the order transaction for deterministic receipts.
  ///
  /// [registry] resolves the models the demo providers read and write.
  const FoodioEffects(this.registry, {this.clock = const FoodioClock()});

  /// Registered models the providers read and write through typed fields.
  final BeakModelRegistry registry;

  /// Source for provider receipt and message timestamps.
  final FoodioClock clock;

  static const _orders = OrderModel();

  /// Enqueues persistent effects only after the complete graph validates.
  Future<void> finalize(
    BeakSavePlan plan,
    BeakSaveResult result,
    WormDataSource transaction,
    BeakPrincipal? principal,
  ) async {
    if (!plan.root.isOf(_orders)) return;
    final rootId = plan.root.id ?? result.identities[plan.root.draftId];
    if (rootId == null) return;
    final record = await transaction.find(_orders, rootId);
    if (record == null) return;
    final status = OrderModel.status.readFrom(record);
    if (status == OrderStatus.draft) return;
    // --8<-- [start:foodioQueueEffect]
    Future<void> queue(FoodioEffectKind kind, {String? recipient}) =>
        BeakOutbox.enqueue(
          transaction.adapter,
          key: '${plan.saveId}:${kind.name}',
          kind: kind.name,
          payload: const FoodioEffectPayloadModel().record([
            FoodioEffectPayloadModel.orderId.to('$rootId'),
            FoodioEffectPayloadModel.amountInCents.to(
              OrderModel.grossCents.readFrom(record) ?? 0,
            ),
            FoodioEffectPayloadModel.reference.to(
              OrderModel.reference.readFrom(record),
            ),
            FoodioEffectPayloadModel.recipient.to(
              recipient ?? OrderModel.customerEmail.readFrom(record) ?? '',
            ),
            FoodioEffectPayloadModel.paymentMethodId.to(
              OrderModel.paymentMethodId.readFrom(record),
            ),
            FoodioEffectPayloadModel.paymentMode.to(
              OrderModel.paymentMode.readFrom(record),
            ),
          ]),
        );
    // --8<-- [end:foodioQueueEffect]
    // --8<-- [start:foodioQueueOnPlace]
    if (plan.runs(OrderActions.place)) {
      if (OrderModel.sendConfirmation.readFrom(record) == true) {
        await queue(FoodioEffectKind.confirmation);
      }
      if (OrderModel.paymentStatus.readFrom(record) == PaymentStatus.pending) {
        if (OrderModel.paymentMode.readFrom(record) == 'paymentLink') {
          await queue(FoodioEffectKind.paymentLink);
        } else {
          await queue(FoodioEffectKind.charge);
        }
      }
    }
    // --8<-- [end:foodioQueueOnPlace]
    // A changed payment mode also creates a durable request. The prepared
    // patch contains pending only when the authoritative workflow permits it.
    final paymentChanged =
        plan.action == null &&
        plan.operations.any(
          (operation) =>
              operation.target == plan.root &&
              operation.sets(OrderModel.paymentStatus) &&
              OrderModel.paymentStatus.readFrom(operation.values) ==
                  PaymentStatus.pending,
        );
    if (paymentChanged) {
      await queue(
        OrderModel.paymentMode.readFrom(record) == 'paymentLink'
            ? FoodioEffectKind.paymentLink
            : FoodioEffectKind.charge,
      );
    }
    if (plan.runs(OrderActions.retryPayment)) {
      await queue(FoodioEffectKind.charge);
    }
    if (plan.runs(OrderActions.sendPaymentLink)) {
      await queue(FoodioEffectKind.paymentLink);
    }
    if ((plan.runs(OrderActions.place) &&
            OrderModel.approvalStatus.readFrom(record) ==
                ApprovalStatus.pending) ||
        plan.runs(OrderActions.requestApproval)) {
      final profileId = OrderModel.profileId.readFrom(record);
      final profile = profileId == null
          ? null
          : await transaction.find(const DeliveryProfileModel(), profileId);
      final approverId = profile == null
          ? null
          : DeliveryProfileModel.approverId.readFrom(profile);
      final approver = approverId == null
          ? null
          : await transaction.find(const StaffMemberModel(), approverId);
      await queue(
        FoodioEffectKind.approval,
        recipient: approver == null
            ? ''
            : StaffMemberModel.email.readFrom(approver),
      );
    }
    if (plan.runsAny([OrderActions.cancel, OrderActions.reject]) &&
        OrderModel.paymentStatus.readFrom(record) == PaymentStatus.paid) {
      await queue(FoodioEffectKind.refund);
    }
  }

  // --8<-- [start:foodioSchedule]
  /// The demo providers, drained every second while the host serves.
  ///
  /// Each provider persists its receipt through [adapter] by effect key
  /// before acknowledging, so a redelivered effect is a no-op.
  BeakOutboxSchedule schedule(DatabaseAdapter adapter) => BeakOutboxSchedule(
    interval: const Duration(seconds: 1),
    handlers: {
      for (final kind in [
        FoodioEffectKind.confirmation,
        FoodioEffectKind.approval,
        FoodioEffectKind.paymentLink,
      ])
        kind.name: (effect) => _message(adapter, effect, kind),
      FoodioEffectKind.charge.name: (effect) =>
          _payment(adapter, effect, FoodioEffectKind.charge),
      FoodioEffectKind.refund.name: (effect) =>
          _payment(adapter, effect, FoodioEffectKind.refund),
    },
  );
  // --8<-- [end:foodioSchedule]

  /// One worker over the [schedule]'s providers on the demo clock, for a
  /// caller that drains on its own terms, like a test.
  BeakOutboxWorker worker(DatabaseAdapter adapter) =>
      schedule(adapter).worker(adapter, now: clock.read);

  Future<void> _message(
    DatabaseAdapter adapter,
    BeakOutboxEffect effect,
    FoodioEffectKind kind,
  ) => adapter.transaction((tx) async {
    final data = WormDataSource(registry, adapter: tx);
    // --8<-- [start:foodioDeliverOnce]
    if (await data.findWhere(
          const MessageDeliveryModel(),
          MessageDeliveryModel.effectKey.eq(effect.key),
        ) !=
        null) {
      return;
    }
    // --8<-- [end:foodioDeliverOnce]
    final orderId = FoodioEffectPayloadModel.orderId.require(effect.payload);
    final order = await data.find(_orders, orderId);
    if (order == null) {
      throw const BeakNotFoundException('Order no longer exists.');
    }
    final stale =
        OrderModel.status.readFrom(order) == OrderStatus.cancelled ||
        kind == FoodioEffectKind.approval &&
            OrderModel.approvalStatus.readFrom(order) !=
                ApprovalStatus.pending ||
        kind == FoodioEffectKind.paymentLink &&
            (!const {
                  PaymentStatus.unpaid,
                  PaymentStatus.pending,
                  PaymentStatus.failed,
                }.contains(OrderModel.paymentStatus.readFrom(order)) ||
                OrderModel.paymentMode.readFrom(order) !=
                    FoodioEffectPayloadModel.paymentMode.readFrom(
                      effect.payload,
                    ) ||
                OrderModel.grossCents.readFrom(order) !=
                    FoodioEffectPayloadModel.amountInCents.readFrom(
                      effect.payload,
                    ));
    final recipient =
        FoodioEffectPayloadModel.recipient.readFrom(effect.payload) ?? '';
    if (!stale && recipient.isEmpty) {
      throw const BeakValidationException('A recipient is required.');
    }
    final reference =
        FoodioEffectPayloadModel.reference.readFrom(effect.payload) ?? orderId;
    final subject = switch (kind) {
      FoodioEffectKind.approval => 'Approval requested for $reference',
      FoodioEffectKind.paymentLink => 'Payment link for $reference',
      _ => 'Your order $reference is confirmed',
    };
    final body = switch (kind) {
      FoodioEffectKind.paymentLink =>
        'Demo payment link: https://payments.gabel.example/demo/$orderId',
      FoodioEffectKind.approval =>
        'Review this order in Gabel. Company budgets remain enforced.',
      _ =>
        'Your order has been received. Track preparation and delivery in Gabel.',
    };
    final stamp = clock.now;
    await data.insert(const MessageDeliveryModel(), [
      MessageDeliveryModel.id.to(effect.key),
      MessageDeliveryModel.effectKey.to(effect.key),
      MessageDeliveryModel.orderId.to(orderId),
      MessageDeliveryModel.subject.to(subject),
      MessageDeliveryModel.recipient.to(recipient),
      MessageDeliveryModel.body.to(body),
      MessageDeliveryModel.status.to(stale ? 'skipped' : 'delivered'),
      MessageDeliveryModel.processedAt.to(stamp),
      MessageDeliveryModel.createdAt.to(stamp),
      MessageDeliveryModel.updatedAt.to(stamp),
    ]);
    if (!stale && kind == FoodioEffectKind.paymentLink) {
      await data.patch(_orders, orderId, [
        OrderModel.paymentLink.to(
          'https://payments.gabel.example/demo/$orderId',
        ),
        OrderModel.updatedAt.to(_nextOrderRevision(order)),
      ]);
    }
    await _activity(
      data,
      effect,
      kind,
      stale
          ? 'Obsolete ${kind.name} email skipped'
          : '${switch (kind) {
              FoodioEffectKind.approval => 'Approval request',
              FoodioEffectKind.paymentLink => 'Payment link',
              _ => 'Confirmation',
            }} email sent',
      recipient,
    );
  });

  Future<void> _payment(
    DatabaseAdapter adapter,
    BeakOutboxEffect effect,
    FoodioEffectKind kind,
  ) => adapter.transaction((tx) async {
    final data = WormDataSource(registry, adapter: tx);
    if (await data.findWhere(
          const PaymentAttemptModel(),
          PaymentAttemptModel.effectKey.eq(effect.key),
        ) !=
        null) {
      return;
    }
    final orderId = FoodioEffectPayloadModel.orderId.require(effect.payload);
    final order = await data.find(_orders, orderId);
    if (order == null) {
      throw const BeakNotFoundException('Order no longer exists.');
    }
    final methodId = FoodioEffectPayloadModel.paymentMethodId.readFrom(
      effect.payload,
    );
    final method = methodId == null
        ? null
        : await data.find(const PaymentMethodModel(), methodId);
    final amount =
        FoodioEffectPayloadModel.amountInCents.readFrom(effect.payload) ??
        (throw const BeakValidationException(
          'A payment effect must carry its amount in cents.',
        ));
    final cancelled =
        OrderModel.status.readFrom(order) == OrderStatus.cancelled;
    final stale =
        kind == FoodioEffectKind.charge &&
        (cancelled ||
            !const {
              PaymentStatus.pending,
              PaymentStatus.failed,
            }.contains(OrderModel.paymentStatus.readFrom(order)) ||
            OrderModel.grossCents.readFrom(order) != amount ||
            OrderModel.paymentMode.readFrom(order) !=
                FoodioEffectPayloadModel.paymentMode.readFrom(effect.payload) ||
            OrderModel.paymentMethodId.readFrom(order) != methodId);
    final success =
        kind == FoodioEffectKind.refund ||
        method != null &&
            PaymentMethodModel.demoOutcome.readFrom(method) == 'succeeded';
    final status = stale
        ? 'skipped'
        : success
        ? 'succeeded'
        : 'declined';
    final stamp = clock.now;
    await data.insert(const PaymentAttemptModel(), [
      PaymentAttemptModel.id.to(effect.key),
      PaymentAttemptModel.effectKey.to(effect.key),
      PaymentAttemptModel.orderId.to(orderId),
      PaymentAttemptModel.reference.to('DEMO-${effect.key}'),
      PaymentAttemptModel.amountCents.to(amount),
      PaymentAttemptModel.kind.to(kind.name),
      PaymentAttemptModel.status.to(status),
      PaymentAttemptModel.provider.to('gabel-demo'),
      PaymentAttemptModel.processedAt.to(stamp),
      PaymentAttemptModel.createdAt.to(stamp),
      PaymentAttemptModel.updatedAt.to(stamp),
    ]);
    if (!stale) {
      final approvalPending =
          OrderModel.approvalStatus.readFrom(order) == ApprovalStatus.pending;
      final strict = OrderModel.strictAllergy.readFrom(order) == true;
      final acknowledged =
          OrderModel.allergyAcknowledged.readFrom(order) == true;
      final attention = cancelled
          ? const _Attention.none()
          : !success
          ? _Attention('Payment failed', OrderActions.retryPayment)
          : approvalPending
          ? _Attention('Approval needed', OrderActions.requestApproval)
          : strict && !acknowledged
          ? _Attention(
              'Allergy note needs kitchen confirmation',
              OrderActions.acknowledgeAllergy,
            )
          : const _Attention.none();
      await data.patch(_orders, orderId, [
        OrderModel.paymentStatus.to(
          kind == FoodioEffectKind.refund
              ? PaymentStatus.refunded
              : success
              ? PaymentStatus.paid
              : PaymentStatus.failed,
        ),
        OrderModel.needsAttention.to(
          cancelled
              ? false
              : !success || approvalPending || strict && !acknowledged,
        ),
        OrderModel.attentionReason.to(attention.reason),
        OrderModel.nextAction.to(attention.action?.name ?? ''),
        OrderModel.updatedAt.to(_nextOrderRevision(order)),
      ]);
    }
    await _activity(
      data,
      effect,
      kind,
      stale
          ? 'Stale payment request skipped'
          : kind == FoodioEffectKind.refund
          ? 'Payment refunded'
          : success
          ? 'Payment received'
          : 'Payment declined',
      'Persistent demo provider',
    );
  });

  DateTime _nextOrderRevision(BeakRecord order) => beakRevisionTimestamp(
    clock.now,
    previous: OrderModel.updatedAt.readFrom(order),
  );

  Future<void> _activity(
    WormDataSource data,
    BeakOutboxEffect effect,
    FoodioEffectKind kind,
    String title,
    String description,
  ) async {
    final stamp = clock.now;
    await data.insert(const OrderActivityModel(), [
      OrderActivityModel.id.to('effect:${effect.key}'),
      OrderActivityModel.orderId.to(
        FoodioEffectPayloadModel.orderId.require(effect.payload),
      ),
      OrderActivityModel.title.to(title),
      OrderActivityModel.actor.to('Automatic'),
      OrderActivityModel.kind.to(kind.name),
      OrderActivityModel.description.to(description),
      OrderActivityModel.saveKey.to(effect.key),
      OrderActivityModel.occurredAt.to(stamp),
      OrderActivityModel.createdAt.to(stamp),
      OrderActivityModel.updatedAt.to(stamp),
    ]);
  }
}

/// The attention flag a settled payment leaves on its order.
final class _Attention {
  const _Attention(this.reason, BeakModelAction this.action);
  const _Attention.none() : reason = '', action = null;

  final String reason;
  final BeakModelAction? action;
}
