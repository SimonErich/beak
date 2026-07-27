import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The media-asset show page: a headline strip of the title, collection and
/// ordering, then a two-column body that pairs the caption and source URL
/// with a compact placement summary.
const BeakBlock mediaAssetDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Media asset',
      child: BeakFieldGroupBlock([
        MediaAssetColumns.title,
        MediaAssetColumns.collection,
        MediaAssetColumns.sortIndex,
      ], columnCount: 3),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Content',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(MediaAssetColumns.caption),
              BeakFieldBlock(MediaAssetColumns.url),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Placement',
          child: BeakFieldGroupBlock([
            MediaAssetColumns.collection,
            MediaAssetColumns.sortIndex,
          ]),
        ),
      ],
    ),
  ],
);
