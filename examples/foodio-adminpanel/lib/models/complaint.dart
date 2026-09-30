import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'complaint.beak.dart';

/// Complaint configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Complaint extends BeakSchema {
  /// Reference.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String reference;

  /// Order.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Order order;

  /// Subject.
  late final String subject;

  /// Description.
  @Column(defaultValue: '')
  late final String? description;

  /// Status.
  @Column(defaultValue: 'open')
  late final String status;

  /// Assignee.
  @Column(defaultValue: 'Marie Novak')
  late final String assignee;
}
