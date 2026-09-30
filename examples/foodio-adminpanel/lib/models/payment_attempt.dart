import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'payment_attempt.beak.dart';

/// Durable demo provider receipt, visible in the operations panel.
@Resource(timestamps: true)
final class PaymentAttempt extends BeakSchema {
  /// Provider receipt reference.
  @Display()
  late final String reference;

  /// Owning order.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Order order;

  /// Persisted provider idempotency key.
  @Column(unique: true)
  late final String effectKey;

  /// Charged or refunded amount in integer cents.
  late final int amountCents;

  /// Charge or refund.
  late final String kind;

  /// Succeeded, declined or skipped.
  late final String status;

  /// Deterministic demo provider identity.
  @Column(defaultValue: 'gabel-demo')
  late final String provider;

  /// Time the provider durably processed the request.
  late final DateTime processedAt;
}
