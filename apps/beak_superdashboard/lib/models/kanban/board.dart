import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the boards resource.
abstract final class BoardColumns {
  /// Board name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Board description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// The owning user.
  static const ownerId = BeakStringColumn(
    key: 'owner_id',
    label: 'Owner',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    description,
    ownerId,
    SharedColumns.createdAt,
  ];
}

/// Typed relationships of the boards resource.
abstract final class BoardRelations {
  /// The columns on this board.
  static const columns = BeakHasMany(
    key: 'columns',
    label: 'Columns',
    relatedTable: 'board_columns',
    displayColumnKey: 'name',
    foreignKey: 'board_id',
  );

  /// The owning user.
  static const owner = BeakBelongsTo(
    key: 'owner',
    label: 'Owner',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'owner_id',
    searchColumnKeys: ['name'],
  );
}

/// The boards resource — a kanban project board.
final class BoardModel extends BeakModel {
  /// Creates the boards model.
  const BoardModel();

  @override
  String get table => 'boards';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => BoardColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BoardRelations.columns,
    BoardRelations.owner,
  ];
}
