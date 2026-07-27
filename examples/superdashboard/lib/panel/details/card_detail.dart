import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The kanban card layout, shared by the show page and the create/edit form:
/// a headline strip (title, priority, due date, owning column), a two-column
/// body splitting the write-up and counts from the cover image, and tabs for
/// the card's labels and assigned members.
const BeakBlock cardDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Card',
      child: BeakFieldGroupBlock([
        CardColumns.title,
        CardColumns.priority,
        CardColumns.dueDate,
        CardColumns.columnId,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Details',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(CardColumns.description),
              BeakFieldGroupBlock([
                CardColumns.sortIndex,
                CardColumns.attachmentsCount,
                CardColumns.commentsCount,
              ], columnCount: 3),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Cover',
          child: BeakFieldBlock(CardColumns.coverImage),
        ),
      ],
    ),
    BeakTabsBlock(
      tabs: [
        BeakTabBlockItem(
          label: 'Labels',
          content: BeakRelationBlock(CardRelations.labels),
        ),
        BeakTabBlockItem(
          label: 'Members',
          content: BeakRelationBlock(CardRelations.members),
        ),
      ],
    ),
  ],
);
