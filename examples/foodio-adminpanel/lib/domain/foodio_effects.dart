import 'package:beak/migrations.dart';

import '../models/models.dart';
import 'foodio_clock.dart';

/// Atomically enqueues effects. The worker performs them only after commit.
final class FoodioEffects {
  /// Uses the same clock as the order transaction for deterministic receipts.
  const FoodioEffects({this.clock = const FoodioClock()});

  /// Source for provider receipt and message timestamps.
  final FoodioClock clock;

  /// Enqueues persistent effects only after the complete graph validates.
  Future<void> finalize(
    BeakSavePlan plan,
    BeakSaveResult result,
    WormDataSource transaction,
    BeakPrincipal? principal,
  ) async {
    if (plan.root.table != 'orders') return;
    final rootId = plan.root.id ?? result.identities[plan.root.draftId];
    if (rootId == null) return;
    final record = await transaction.getOne('orders', rootId);
    if (record == null) return;
    final status = OrderModel.status.readFrom(record);
    if (status == OrderStatus.draft) return;
    Future<void> queue(String kind, {String? recipient}) => BeakOutbox.enqueue(
      transaction.adapter,
      key: '${plan.saveId}:$kind',
      kind: kind,
      payload: BeakRecord.fromRow({
        'order_id': rootId,
        'amount_cents': OrderModel.grossCents.readFrom(record) ?? 0,
        'reference': OrderModel.reference.readFrom(record),
        'recipient':
            recipient ?? OrderModel.customerEmail.readFrom(record) ?? '',
        'payment_method_id': OrderModel.paymentMethodId.readFrom(record),
        'payment_mode': OrderModel.paymentMode.readFrom(record),
      }),
    );
    if (plan.action == 'place') {
      if (OrderModel.sendConfirmation.readFrom(record) == true) {
        await queue('confirmation');
      }
      if (OrderModel.paymentStatus.readFrom(record) == PaymentStatus.pending) {
        if (OrderModel.paymentMode.readFrom(record) == 'paymentLink') {
          await queue('paymentLink');
        } else {
          await queue('charge');
        }
      }
    }
    // A changed payment mode also creates a durable request. The prepared
    // patch contains pending only when the authoritative workflow permits it.
    final paymentChanged =
        plan.action == null &&
        plan.operations.any(
          (operation) =>
              operation.target == plan.root &&
              operation.values['payment_status']?.raw == 'pending',
        );
    if (paymentChanged) {
      await queue(
        OrderModel.paymentMode.readFrom(record) == 'paymentLink'
            ? 'paymentLink'
            : 'charge',
      );
    }
    if (plan.action == 'retryPayment') await queue('charge');
    if (plan.action == 'sendPaymentLink') await queue('paymentLink');
    if ((plan.action == 'place' &&
            OrderModel.approvalStatus.readFrom(record) ==
                ApprovalStatus.pending) ||
        plan.action == 'requestApproval') {
      final profileId = OrderModel.profileId.readFrom(record);
      final profile = profileId == null
          ? null
          : await transaction.getOne('delivery_profiles', profileId);
      final approverId = profile == null
          ? null
          : DeliveryProfileModel.approverId.readFrom(profile);
      final approver = approverId == null
          ? null
          : await transaction.getOne('staff_members', approverId);
      await queue(
        'approval',
        recipient: approver == null
            ? ''
            : StaffMemberModel.email.readFrom(approver),
      );
    }
    if ({'cancel', 'reject'}.contains(plan.action) &&
        OrderModel.paymentStatus.readFrom(record) == PaymentStatus.paid) {
      await queue('refund');
    }
  }

  /// The provider itself persists receipts by effect key before acknowledging.
  BeakOutboxWorker worker(DatabaseAdapter adapter) => BeakOutboxWorker(
    adapter: adapter,
    now: clock.read,
    handlers: {
      for (final kind in ['confirmation', 'approval', 'paymentLink'])
        kind: (effect) => _message(adapter, effect),
      'charge': (effect) => _payment(adapter, effect),
      'refund': (effect) => _payment(adapter, effect),
    },
  );

  Future<void> _message(
    DatabaseAdapter adapter,
    BeakOutboxEffect effect,
  ) => adapter.transaction((tx) async {
    if (await tx.selectOne(
          QueryDescriptor(
            table: 'message_deliveries',
            where: const Field<String>('effect_key').eq(effect.key),
          ),
        ) !=
        null) {
      return;
    }
    final orderId = effect.payload['order_id']!.raw!;
    final order = await tx.selectOne(
      QueryDescriptor(
        table: 'orders',
        where: const Field<Object>('id').eq(orderId),
      ),
    );
    if (order == null) {
      throw const BeakNotFoundException('Order no longer exists.');
    }
    final stale =
        order['status'] == 'cancelled' ||
        effect.kind == 'approval' && order['approval_status'] != 'pending' ||
        effect.kind == 'paymentLink' &&
            (!{
                  'unpaid',
                  'pending',
                  'failed',
                }.contains(order['payment_status']) ||
                order['payment_mode'] != effect.payload['payment_mode']?.raw ||
                order['gross_cents'] != effect.payload['amount_cents']?.raw);
    final recipient = effect.payload['recipient']?.raw as String? ?? '';
    if (!stale && recipient.isEmpty) {
      throw const BeakValidationException('A recipient is required.');
    }
    final reference = effect.payload['reference']?.raw ?? orderId;
    final subject = switch (effect.kind) {
      'approval' => 'Approval requested for $reference',
      'paymentLink' => 'Payment link for $reference',
      _ => 'Your order $reference is confirmed',
    };
    final body = effect.kind == 'paymentLink'
        ? 'Demo payment link: https://payments.gabel.example/demo/$orderId'
        : effect.kind == 'approval'
        ? 'Review this order in Gabel. Company budgets remain enforced.'
        : 'Your order has been received. Track preparation and delivery in Gabel.';
    final stamp = clock.now.toIso8601String();
    await tx.insert(
      InsertDescriptor(
        table: 'message_deliveries',
        values: {
          'id': effect.key,
          'effect_key': effect.key,
          'order_id': orderId,
          'subject': subject,
          'recipient': recipient,
          'body': body,
          'status': stale ? 'skipped' : 'delivered',
          'processed_at': stamp,
          'created_at': stamp,
          'updated_at': stamp,
        },
      ),
    );
    if (!stale && effect.kind == 'paymentLink') {
      await tx.update(
        UpdateDescriptor(
          table: 'orders',
          values: {
            'payment_link': 'https://payments.gabel.example/demo/$orderId',
            'updated_at': _nextOrderRevision(order),
          },
          where: const Field<Object>('id').eq(orderId),
        ),
      );
    }
    await _activity(
      tx,
      effect,
      stale
          ? 'Obsolete ${effect.kind} email skipped'
          : '${effect.kind == 'approval'
                ? 'Approval request'
                : effect.kind == 'paymentLink'
                ? 'Payment link'
                : 'Confirmation'} email sent',
      recipient,
    );
  });

  Future<void> _payment(DatabaseAdapter adapter, BeakOutboxEffect effect) =>
      adapter.transaction((tx) async {
        if (await tx.selectOne(
              QueryDescriptor(
                table: 'payment_attempts',
                where: const Field<String>('effect_key').eq(effect.key),
              ),
            ) !=
            null) {
          return;
        }
        final orderId = effect.payload['order_id']!.raw!;
        final order = await tx.selectOne(
          QueryDescriptor(
            table: 'orders',
            where: const Field<Object>('id').eq(orderId),
          ),
        );
        if (order == null) {
          throw const BeakNotFoundException('Order no longer exists.');
        }
        final methodId = effect.payload['payment_method_id']?.raw;
        final method = methodId == null
            ? null
            : await tx.selectOne(
                QueryDescriptor(
                  table: 'payment_methods',
                  where: const Field<Object>('id').eq(methodId),
                ),
              );
        final amount = effect.payload['amount_cents']!.raw! as int;
        final cancelled = order['status'] == 'cancelled';
        final stale =
            effect.kind == 'charge' &&
            (cancelled ||
                !{'pending', 'failed'}.contains(order['payment_status']) ||
                order['gross_cents'] != amount ||
                order['payment_mode'] != effect.payload['payment_mode']?.raw ||
                order['payment_method_id'] != methodId);
        final success =
            effect.kind == 'refund' || method?['demo_outcome'] == 'succeeded';
        final status = stale
            ? 'skipped'
            : success
            ? 'succeeded'
            : 'declined';
        final stamp = clock.now.toIso8601String();
        await tx.insert(
          InsertDescriptor(
            table: 'payment_attempts',
            values: {
              'id': effect.key,
              'effect_key': effect.key,
              'order_id': orderId,
              'reference': 'DEMO-${effect.key}',
              'amount_cents': amount,
              'kind': effect.kind,
              'status': status,
              'provider': 'gabel-demo',
              'processed_at': stamp,
              'created_at': stamp,
              'updated_at': stamp,
            },
          ),
        );
        if (!stale) {
          final approvalPending = order['approval_status'] == 'pending';
          final strict =
              order['strict_allergy'] == true || order['strict_allergy'] == 1;
          final acknowledged =
              order['allergy_acknowledged'] == true ||
              order['allergy_acknowledged'] == 1;
          await tx.update(
            UpdateDescriptor(
              table: 'orders',
              where: const Field<Object>('id').eq(orderId),
              values: {
                'payment_status': effect.kind == 'refund'
                    ? 'refunded'
                    : success
                    ? 'paid'
                    : 'failed',
                'needs_attention': cancelled
                    ? false
                    : !success || approvalPending || strict && !acknowledged,
                'attention_reason': cancelled
                    ? ''
                    : !success
                    ? 'Payment failed'
                    : approvalPending
                    ? 'Approval needed'
                    : strict && !acknowledged
                    ? 'Allergy note needs kitchen confirmation'
                    : '',
                'next_action': cancelled
                    ? ''
                    : !success
                    ? 'retryPayment'
                    : approvalPending
                    ? 'requestApproval'
                    : strict && !acknowledged
                    ? 'acknowledgeAllergy'
                    : '',
                'updated_at': _nextOrderRevision(order),
              },
            ),
          );
        }
        await _activity(
          tx,
          effect,
          stale
              ? 'Stale payment request skipped'
              : effect.kind == 'refund'
              ? 'Payment refunded'
              : success
              ? 'Payment received'
              : 'Payment declined',
          'Persistent demo provider',
        );
      });

  DateTime _nextOrderRevision(Map<String, Object?> order) =>
      beakRevisionTimestamp(
        clock.now,
        previous: switch (order['updated_at']) {
          final DateTime value => value,
          final String value => DateTime.tryParse(value),
          _ => null,
        },
      );

  Future<void> _activity(
    DatabaseAdapter tx,
    BeakOutboxEffect effect,
    String title,
    String description,
  ) async {
    final stamp = clock.now.toIso8601String();
    await tx.insert(
      InsertDescriptor(
        table: 'order_activities',
        values: {
          'id': 'effect:${effect.key}',
          'order_id': effect.payload['order_id']!.raw,
          'title': title,
          'actor': 'Automatic',
          'kind': effect.kind,
          'description': description,
          'save_key': effect.key,
          'occurred_at': stamp,
          'created_at': stamp,
          'updated_at': stamp,
        },
      ),
    );
  }
}
