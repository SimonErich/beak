import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'board.dart';
import 'card.dart';

part 'board_column.beak.dart';

/// The board-columns resource — a lane on a kanban board.
@Resource()
final class BoardColumn extends BeakSchema {
  /// The owning board.
  @BelongsTo()
  late final Board? board;

  /// Column name, e.g. `In progress`.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(60)])
  late final String name;

  /// Left-to-right ordering.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;

  /// Column accent color.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? color;

  /// Optional work-in-progress limit.
  @Column(
    label: 'WIP limit',
    visibleOn: {BeakContext.form, BeakContext.detail},
    min: 0,
  )
  late final int? wipLimit;

  /// The cards in this column.
  @HasMany(foreignKey: 'column_id')
  late final List<Card> cards;
}
