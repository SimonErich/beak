import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the board-columns resource — the lanes of a kanban
/// board.
abstract final class BoardColumnColumns {
  /// The owning board.
  static const boardId = BeakStringColumn(
    key: 'board_id',
    label: 'Board',
    visibleOn: {BeakContext.form},
  );

  /// Column name, e.g. `In progress`.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Left-to-right ordering.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// Column accent color.
  static const color = BeakColorColumn(
    key: 'color',
    label: 'Color',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Optional work-in-progress limit.
  static const wipLimit = BeakIntColumn(
    key: 'wip_limit',
    label: 'WIP limit',
    min: 0,
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    boardId,
    name,
    sortIndex,
    color,
    wipLimit,
  ];
}

/// Typed relationships of the board-columns resource.
abstract final class BoardColumnRelations {
  /// The owning board.
  static const board = BeakBelongsTo(
    key: 'board',
    label: 'Board',
    relatedTable: 'boards',
    displayColumnKey: 'name',
    foreignKey: 'board_id',
    searchColumnKeys: ['name'],
  );

  /// The cards in this column.
  static const cards = BeakHasMany(
    key: 'cards',
    label: 'Cards',
    relatedTable: 'cards',
    displayColumnKey: 'title',
    foreignKey: 'column_id',
  );
}

/// The board-columns resource — a lane on a kanban board.
final class BoardColumnModel extends BeakModel {
  /// Creates the board-columns model.
  const BoardColumnModel();

  @override
  String get table => 'board_columns';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => BoardColumnColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BoardColumnRelations.board,
    BoardColumnRelations.cards,
  ];
}
