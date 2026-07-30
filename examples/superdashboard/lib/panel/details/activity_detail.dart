import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The activity show page: a headline strip of the entry's kind, author and
/// target, a two-column body splitting the message from its threading context,
/// and an inline table of the replies to this entry.
const BeakBlock activityDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Activity',
      child: BeakFieldGroupBlock([
        ActivityColumns.type,
        ActivityColumns.userId,
        ActivityColumns.target,
      ], columnCount: 3),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Message',
          child: BeakColumnBlock(
            children: [BeakFieldBlock(ActivityColumns.body)],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Thread',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ActivityColumns.parentId),
              BeakFieldBlock(ActivityColumns.userId),
            ],
          ),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Replies',
      child: BeakRelationBlock(ActivityRelations.replies),
    ),
  ],
);
