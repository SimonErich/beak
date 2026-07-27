import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The board show page: a headline strip naming the board and its owner, the
/// description on its own full-width row, and a card listing the board's
/// columns relation.
const BeakBlock boardDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Board',
      child: BeakFieldGroupBlock([
        BoardColumns.name,
        BoardColumns.ownerId,
      ], columnCount: 2),
    ),
    BeakCardBlock(
      title: 'Description',
      child: BeakFieldBlock(BoardColumns.description),
    ),
    BeakCardBlock(
      title: 'Columns',
      child: BeakRelationBlock(BoardRelations.columns),
    ),
  ],
);
