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
///   groupField: TaskModel.status,
///   titleField: TaskModel.title.column,
///   subtitleField: TaskModel.assignee.column,
///   onCardMove: (record) => lastMoved.value = TaskModel.id.readFrom(record),
/// );
/// ```
final class BeakKanbanBlock extends BeakBlock {
  /// Creates a Kanban block over [model], grouped by [groupField].
  const BeakKanbanBlock({
    required this.model,
    required this.groupField,
    required this.titleField,
    this.subtitleField,
    this.sortField,
    this.sortDescending = false,
    this.label = 'Board',
    this.onCardMove,
    super.span,
  });

  /// The model whose records become cards.
  final BeakModel model;

  /// The enum field whose values define the board's columns.
  final BeakScalarField<Enum> groupField;

  /// The enum column behind [groupField].
  ///
  /// Throws a [BeakConfigurationException] when [groupField] is not an enum
  /// column of [model] itself.
  BeakEnumColumn<Enum> get groupColumn => switch (groupField.column) {
    final BeakEnumColumn<Enum> column
        when groupField.path.isEmpty && groupField.model.table == model.table =>
      column,
    _ => throw BeakConfigurationException(
      'Kanban group field "${groupField.qualifiedKey}" must be an enum field '
      'of ${model.table}.',
    ),
  };

  /// Column supplying each card's title.
  final BeakColumn titleField;

  /// Column supplying each card's subtitle, when bound.
  final BeakColumn? subtitleField;

  /// Column ordering the cards within each column, when bound — without it
  /// the card order is whatever the data source returns.
  final BeakColumn? sortField;

  /// Whether [sortField] orders descending.
  final bool sortDescending;

  /// Accessibility label for the board.
  final String label;

  /// Invoked with a card's record after it is dropped in a new column; the
  /// block first persists the new group through the data source.
  final void Function(BeakRecord record)? onCardMove;
}
