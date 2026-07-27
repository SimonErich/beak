import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The FAQ show page: a headline strip of the question and its placement, then
/// a two-column body that gives the full question-and-answer write-up the room
/// it needs beside a compact card of category and ordering metadata.
const BeakBlock faqDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'FAQ',
      child: BeakFieldGroupBlock([
        FaqColumns.question,
        FaqColumns.categoryId,
        FaqColumns.featured,
        FaqColumns.sortIndex,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Question & answer',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(FaqColumns.question),
              BeakFieldBlock(FaqColumns.answer),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Placement',
          child: BeakFieldGroupBlock([
            FaqColumns.categoryId,
            FaqColumns.featured,
            FaqColumns.sortIndex,
          ], columnCount: 2),
        ),
      ],
    ),
  ],
);
