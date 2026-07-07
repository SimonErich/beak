import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// The kind of an activity-feed entry.
enum ActivityType {
  /// A comment.
  comment,

  /// A mention of another user.
  mention,

  /// An upload.
  upload,

  /// A status change.
  statusChange,

  /// A reaction.
  reaction,
}

/// Typed columns of the activity resource — a self-referential feed where a
/// reply points at its parent entry.
abstract final class ActivityColumns {
  /// The author.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'User',
    visibleOn: {BeakContext.form},
  );

  /// The kind of entry, shown as a colored badge.
  static const type = BeakEnumColumn<ActivityType>(
    key: 'type',
    label: 'Type',
    values: ActivityType.values,
    defaultValue: ActivityType.comment,
    filterable: true,
    badgeColors: {
      ActivityType.comment: BeakColor.primary,
      ActivityType.mention: BeakColor.info,
      ActivityType.upload: BeakColor.success,
      ActivityType.statusChange: BeakColor.warning,
      ActivityType.reaction: BeakColor.muted,
    },
  );

  /// The entry body.
  static const body = BeakTextColumn(
    key: 'body',
    label: 'Body',
    searchable: true,
    rules: [BeakRequired()],
  );

  /// The thing the entry is about (a record label, a page name).
  static const target = BeakStringColumn(
    key: 'target',
    label: 'Target',
    rules: [BeakMaxLength(160)],
  );

  /// Parent entry when this is a reply (self-referential FK).
  static const parentId = BeakStringColumn(
    key: 'parent_id',
    label: 'In reply to',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    userId,
    type,
    body,
    target,
    parentId,
    SharedColumns.createdAt,
  ];
}

/// Typed relationships of the activity resource.
abstract final class ActivityRelations {
  /// The author.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'User',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name'],
  );

  /// The parent entry this one replies to (self-referential).
  static const parent = BeakBelongsTo(
    key: 'parent',
    label: 'Parent',
    relatedTable: 'activities',
    displayColumnKey: 'body',
    foreignKey: 'parent_id',
  );

  /// The replies to this entry (self-referential).
  static const replies = BeakHasMany(
    key: 'replies',
    label: 'Replies',
    relatedTable: 'activities',
    displayColumnKey: 'body',
    foreignKey: 'parent_id',
  );
}

/// The activity resource — a threaded feed of comments and events.
final class ActivityModel extends BeakModel {
  /// Creates the activity model.
  const ActivityModel();

  @override
  String get table => 'activities';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => ActivityColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ActivityRelations.user,
    ActivityRelations.parent,
    ActivityRelations.replies,
  ];
}
