import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'order_activity.beak.dart';

/// OrderActivity configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class OrderActivity extends BeakSchema {
  /// Title.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String title;

  /// Order.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Order order;

  /// Actor.
  @Column(defaultValue: 'System')
  late final String actor;

  /// Kind.
  @Column(defaultValue: 'event')
  late final String kind;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;

  /// Save key.
  late final String saveKey;

  /// Occurred at.
  @Column(sortable: true, filterable: true)
  late final DateTime occurredAt;
}
