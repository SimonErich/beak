# A kanban view

> Map model fields to a specialized workflow board.

Place a `BeakKanbanBlock` on a custom screen and configure its model, grouping fields and callbacks. Use shared model actions for state transitions so drag interactions obey the same rules as forms. The block contract is shown below.

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
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
///   // The board needs the typed enum column, which the generated
///   // TaskColumns keeps; `TaskModel.status.column` is a plain BeakColumn.
///   groupField: TaskColumns.status,
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

  /// The enum column whose values define the board's columns.
  final BeakEnumColumn<Enum> groupField;

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
```

## Continue reading

- [Related guide](../panel/actions.md)
- [All recipes](index.md)
