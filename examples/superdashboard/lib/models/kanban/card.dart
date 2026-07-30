import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import '../shared/enums.dart';
import 'board_column.dart';
import 'card_label.dart';

part 'card.beak.dart';

/// The cards resource — a kanban card.
@Resource()
final class Card extends BeakSchema {
  /// The owning column.
  @BelongsTo()
  late final BoardColumn? column;

  /// Card title.
  @Display()
  @Column(sortable: true, searchable: true, rules: [BeakMaxLength(200)])
  late final String title;

  /// Card description.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// Due date.
  @Column(label: 'Due', sortable: true, format: BeakDateFormat.relative)
  late final DateTime? dueDate;

  /// Priority, shown as a colored badge.
  @Column(filterable: true, defaultValue: Priority.medium)
  @Badges({
    Priority.low: BeakColor.muted,
    Priority.medium: BeakColor.info,
    Priority.high: BeakColor.warning,
    Priority.urgent: BeakColor.error,
  })
  late final Priority? priority;

  /// Optional cover image.
  @Image(
    storagePath: 'kanban/covers',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  )
  @Column(label: 'Cover', visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakImageRef? coverImage;

  /// Vertical ordering within a column.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;

  /// Denormalized attachment count.
  @Column(label: 'Attachments', visibleOn: {BeakContext.detail}, min: 0)
  late final int? attachmentsCount;

  /// Denormalized comment count.
  @Column(label: 'Comments', visibleOn: {BeakContext.detail}, min: 0)
  late final int? commentsCount;

  /// The card's labels, via the `card_card_label` pivot.
  @BelongsToMany()
  late final List<CardLabel> labels;

  /// The assigned members, via the `card_user` pivot.
  @BelongsToMany()
  late final List<User> members;
}
