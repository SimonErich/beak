# A kanban view

> Show a model as a board with one column per value of an enum field, register it as a page, and know what a dropped card writes.

You want the chores of the aviary on a board: one column per status, a card per chore, and dragging a card to another column changes its status.

## Recipe

The board needs a model with an enum field for the columns, and a title for the cards. The showcase's `Task` has both, and the enum carries a colour per value, which the board reuses:

```dart title="examples/showcase/lib/resources/tasks/models/task.dart"
/// Where a task stands; the columns of the board.
enum TaskStatus {
  /// Not started.
  todo,

  /// Being worked on.
  doing,

  /// Finished.
  done,
}
```

```dart title="examples/showcase/lib/resources/tasks/models/task.dart"
@Column(defaultValue: TaskStatus.todo, filterable: true)
@Badges<TaskStatus>({
  TaskStatus.todo: BeakColor.muted,
  TaskStatus.doing: BeakColor.info,
  TaskStatus.done: BeakColor.success,
})
late final TaskStatus status;
```

A board is a data block, and a block lives on a page. Put a `BeakKanbanBlock` in a `BeakScreen`:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _board() => BeakKanbanBlock(
  model: const TaskModel(),
  groupField: TaskModel.status,
  titleField: TaskModel.title.column,
  subtitleField: TaskModel.category.column,
  sortField: TaskModel.position.column,
  label: 'Chores',
);
```

`groupField` is the generated reference to the enum field, `titleField` and `subtitleField` are the columns drawn on each card, and `sortField` orders the cards inside a column. The showcase wraps the board and a calendar of the same model in tabs:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakScreen plannerPage() => BeakScreen(
  path: '/planner',
  title: 'Planner',
  icon: const BeakIconToken(OiIcons.kanban),
  navigationGroup: 'Blocks',
  framed: false,
  body: BeakTabsBlock(
    tabs: [
      BeakTabBlockItem(label: 'Board', content: _board()),
      BeakTabBlockItem(label: 'Calendar', content: _calendar()),
    ],
  ),
);
```

`framed: false` drops the page header and gutters so the board gets the whole viewport. For a board on its own, pass the block as `body:` directly.

Register the page. In an authored panel it is a line in `pages:`:

```dart title="examples/showcase/lib/main.dart"
pages: [
  dataBlocksPage(),
  layoutBlocksPage(),
  contentBlocksPage(),
  plannerPage(),
  chartBlocksPage(),
  mapBlocksPage(),
  chatPage(),
  inboxPage(),
  filesPage(),
  mediaPage(),
  documentsPage(),
  faqPage(),
],
```

In a generated panel, put the `BeakScreen` (a top-level variable with an explicit type, or a function without required arguments) under `lib/screens/` and run `beak prepare`. See [Custom screens](../panel/custom-screens.md#register-it).

## How it works

- The columns are the enum's values, in declaration order, with each value's label and badge colour. There are no free-text swimlanes to keep in step with the model. An empty status still gets a column.
- A record whose status is empty or not one of the enum values appears in no column.
- `groupField` must be an enum field of the block's own model. A relation path or a non-enum field throws `Kanban group field "x" must be an enum field of tasks.` when the board renders.
- The block reads one page of at most 200 records, or of its `filter`, and reads again whenever the table is written, from this screen or another. When more records match, a line beneath the board says `Showing the first 200 of 340.`
- Cards show the stored value of `titleField` and `subtitleField`. An enum subtitle reads `feeding`, not the label you gave it.

Dropping a card saves the new enum name into `groupField` through the panel's data source, as a single-operation graph commit, the way a form saves. The server validates the value with the column's rules and the account's field and row policies, and runs the model's behavior and rules. If that succeeds the block keeps the card in its new column and calls `onCardMove`. If it fails, the card snaps back, a toast gives the reason, and `onCardMove` is not called.

The `position` column in the showcase is only the sort key. A drop writes the status and leaves `position` alone, so the order inside a column is not saved by dragging.

## Variations

| You want | Do this |
| --- | --- |
| To react when a card is dropped | `onCardMove: (record) => ...`. It runs once the server has accepted the move, and not when it refuses. |
| The newest card first | `sortDescending: true` |
| The board in a dashboard grid | `span:` on the block, inside a `BeakGridBlock`, see [Dashboards](../panel/dashboards.md). |
| A board of one owner's cards | `filter:` built from the model's generated fields, an equality on an owner column, say. A row policy on the server narrows it for everyone, see [Auth and policies](../backend/auth-and-policies.md). |
| A move that follows a business rule | The drop is a graph commit, so the model's `behavior` and preparer rules run and a `graphOnly` model accepts it. A transition that needs input or a named guard still belongs to a model action, see [A row action](a-row-action.md). |
| The same records as events on a calendar | `BeakCalendarBlock`, next to the board in the same tabs. |

## Verify

The block tests build a board against a fake source, check the columns, drop a card and check that the new group is written:

```console
$ cd packages/beak_frontend
$ flutter test test/src/blocks/beak_module_blocks_test.dart --name 'BeakKanbanBlock|kanban' --reporter expanded
00:00 +0: BeakKanbanBlock one column per enum value, records grouped
00:00 +1: BeakKanbanBlock the group field must be an enum field of the block model
00:00 +2: BeakKanbanBlock dropping a card persists its new group
00:00 +3: module hardening (audit regressions) kanban fetches one full sorted page
00:00 +4: module hardening (audit regressions) a dropped kanban card stays in its new column
00:00 +5: module blocks read a filtered, bounded page kanban, calendar and chat send their filter
00:00 +6: All tests passed!
```

The planner page renders in the showcase panel:

```console
$ cd examples/showcase
$ flutter test test/aviary_pages_test.dart --name Planner --reporter expanded
00:00 +0: Planner renders
00:00 +1: All tests passed!
```

To see it, run the showcase API on port 8082 and the panel, open Planner and drag a chore from `todo` to `doing`.

## Continue reading

- [A dashboard KPI](a-dashboard-kpi.md) puts a number from the same tasks on a page.
- [View modes](../panel/view-modes.md) covers the board, the calendar and the timeline together.
- [Data blocks](../blocks/data-blocks.md) lists every parameter of the data-bound blocks.
