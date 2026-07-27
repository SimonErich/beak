import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'user.dart';

part 'activity.beak.dart';

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

/// The activity resource — a threaded feed of comments and events.
@Resource(timestamps: true)
final class Activity extends BeakSchema {
  /// The author.
  @BelongsTo()
  late final User? user;

  /// The kind of entry, shown as a colored badge.
  @Column(filterable: true, defaultValue: ActivityType.comment)
  @Badges({
    ActivityType.comment: BeakColor.primary,
    ActivityType.mention: BeakColor.info,
    ActivityType.upload: BeakColor.success,
    ActivityType.statusChange: BeakColor.warning,
    ActivityType.reaction: BeakColor.muted,
  })
  late final ActivityType? type;

  /// The entry body.
  @Display()
  @Column(searchable: true)
  late final BeakText body;

  /// The thing the entry is about (a record label, a page name).
  @Column(rules: [BeakMaxLength(160)])
  late final String? target;

  /// Parent entry when this is a reply (self-referential FK).
  @BelongsTo()
  late final Activity? parent;

  /// The replies to this entry (self-referential).
  @HasMany(foreignKey: 'parent_id')
  late final List<Activity> replies;
}
