import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'message_delivery.beak.dart';

/// Durable demo provider receipt, visible in the operations panel.
@Resource(timestamps: true)
final class MessageDelivery extends BeakSchema {
  /// Message subject.
  @Display()
  late final String subject;

  /// Owning order.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Order order;

  /// Persisted provider idempotency key.
  @Column(unique: true)
  late final String effectKey;

  /// Recipient address.
  late final String recipient;

  /// Content retained by the local demo mail adapter.
  late final String body;

  /// Delivery status, retained across server restarts.
  @Column(defaultValue: 'delivered')
  late final String status;

  /// Time the local demo adapter accepted the message.
  late final DateTime processedAt;
}
