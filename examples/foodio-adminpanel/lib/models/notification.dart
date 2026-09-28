import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'notification.beak.dart';

/// Notification configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Notification extends BeakSchema {
  /// Title.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String title;

  /// Body.
  @Column(defaultValue: '')
  late final String? body;

  /// Recipient.
  @Column(defaultValue: 'Marie Novak')
  late final String recipient;

  /// Order.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Order? order;

  /// Is read.
  @Column(defaultValue: false)
  late final bool isRead;

  /// Occurred at.
  @Column(sortable: true, filterable: true)
  late final DateTime occurredAt;
}
