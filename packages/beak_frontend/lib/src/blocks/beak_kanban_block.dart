part of 'beak_block.dart';

/// A data-bound Kanban board: one column per value of an enum field, each
/// holding the records whose [groupField] matches, rendered on `OiKanban`.
///
/// The board's columns come straight from [groupField]'s declared enum
/// values — using each value's label and badge color — so there are no
/// stringly-typed swimlanes. [titleField] and [subtitleField] draw each
/// card. Dragging a card to another column persists the new group through
/// `dataSource.update` (writing [groupField]) and then notifies [onCardMove].
///
/// ```dart
/// BeakKanbanBlock(
///   model: const TaskModel(),
///   groupField: TaskColumns.status, // a BeakEnumColumn
///   titleField: TaskColumns.title,
///   subtitleField: TaskColumns.assignee,
///   onCardMove: (record) => print('moved ${record[TaskColumns.id.key]?.raw}'),
/// );
/// ```
final class BeakKanbanBlock extends BeakBlock {
  /// Creates a Kanban block over [model], grouped by [groupField].
  const BeakKanbanBlock({
    required this.model,
    required this.groupField,
    required this.titleField,
    this.subtitleField,
    this.label = 'Board',
    this.onCardMove,
    super.span,
  });

  /// The model whose records become cards.
  final BeakModel model;

  /// The enum column whose values define the board's columns.
  final BeakEnumColumn<Enum> groupField;

  /// Column supplying each card's title.
  final BeakColumn titleField;

  /// Column supplying each card's subtitle, when bound.
  final BeakColumn? subtitleField;

  /// Accessibility label for the board.
  final String label;

  /// Invoked with a card's record after it is dropped in a new column; the
  /// block first persists the new group through the data source.
  final void Function(BeakRecord record)? onCardMove;
}
