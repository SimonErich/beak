---
title: View modes
description: Look at one model as a table, a kanban board, a calendar or a timeline, with the resource list plus data blocks on a BeakScreen.
type: guide
audience: [beginner, expert]
status: stable
---

# View modes

A model is a set of records, and a view mode is one way to look at them. The table is the resource's list. The board, the calendar and the timeline are data blocks that you put on a `BeakScreen`. There is no switcher on the list page. If you want one, a tab block over the blocks does it, and the showcase planner below is exactly that.

## At a glance

| Mode | Built with |
| --- | --- |
| Table | `BeakTableScreen` on the resource, plain or [composed](composed-lists.md) |
| Table on a page | `BeakTableBlock` on a `BeakScreen` |
| Board | `BeakKanbanBlock`, one column per value of an enum field |
| Calendar | `BeakCalendarBlock`, events placed by a start and an end column |
| Timeline | `BeakTimelineBlock`, fed by its own `BeakQuerySpec` |
| A switch between them | `BeakTabsBlock`, on a `BeakScreen` with `framed: false` |

The board and the calendar write back: a dropped card and a dragged event save the record through the panel's data source, the way a form saves, see [Writing from a view](#writing-from-a-view).

## One model, three looks

The showcase's `Task` is a chore on the aviary's board. Its resource is an ordinary table:

```dart title="examples/showcase/lib/resources/tasks/task_resource.dart"
--8<-- "examples/showcase/lib/resources/tasks/task_resource.dart"
```

The board takes its columns from the status enum, so each value already has a label and a badge color:

```dart title="examples/showcase/lib/resources/tasks/models/task.dart"
--8<-- "examples/showcase/lib/resources/tasks/models/task.dart:taskStatusBadges"
```

The planner page puts the same model on a board and a calendar behind two tabs:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:plannerPage"
```

`framed: false` drops the page header, the gutters and the scrolling that a `BeakScreen` normally adds, which is what a board or a calendar wants. `BeakTabsBlock` builds only the selected tab's block, so switching a tab mounts the other block and loads its records. Register the screen in `pages:` and it gets a route and a sidebar entry, see [Custom screens](custom-screens.md).

A `BeakTableBlock` puts the table itself on a screen, beside a board if you like. It takes `fields`, `initialSpec` and `baseFilter`, and [Dashboards](dashboards.md) shows it at work.

## The board

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:board"
```

`groupField` must be an enum field of the block's own model. A relation path or a non-enum field throws `Kanban group field "x" must be an enum field of tasks.` when the board renders. The board has one column for every enum value, in declaration order, even an empty one. A record whose group value is empty or unknown appears in no column.

Cards show `titleField` and, when set, `subtitleField`. Both are plain columns of the model (`TaskModel.title.column`) and their text is the stored value. An enum subtitle therefore reads `feeding`, not the label you gave it. `sortField` orders the cards inside a column, and without it the order is whatever the data source returns.

Dropping a card writes the new enum name into `groupField`. It does not renumber `position`, so an order inside a column is not saved.

## The calendar

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:calendar"
```

Every record becomes one event. `titleField` labels it, `startField` places it and `endField` closes it. Without an end the event ends where it starts, and a record with no start is left out, because it has no place on a calendar. `allDayField` is a boolean column, and a `categoryField` that is an enum column tints each event with the badge color of its value. `mode` (`OiCalendarMode.day`, `week` or `month`) is the view it opens in, `month` by default.

Tapping an event calls `onEventTap` with the record. Dragging one writes the new start, and the new end when `endField` is set, and then calls `onEventMove`.

## The timeline

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:taskTimeline"
```

The timeline takes a whole `BeakQuerySpec`, so it is the one block here where you choose the filter, the sort and the page size yourself. Events are sorted newest first by `timeField`, and a record with no time is left out. It is read-only.

## Writing from a view

A dropped card or a dragged event is saved as a single-operation graph commit on that record, through `POST /api/commits`. The server validates the changed value with the column's rules, applies the account's row and field policies, and runs the model's behavior and rules, so a `graphOnly` model or one with `behavior` accepts the move. When the save succeeds, the block mirrors it, so the card stays in its new column, and `onCardMove` or `onEventMove` runs. When it fails, the card snaps back, a toast gives the reason (the server's message for a validation or permission failure, a generic line for an infrastructure one), and the callback does not run. Treat the callbacks as "the write worked".

A transition that needs input, or a guard that has a name, still belongs in a model action on a table. The action runs through the graph commit, gets its rules checked and leaves a receipt, see [Actions](actions.md). A drop can only write the value the column takes.

!!! note "Coming from viewModes"
    Earlier drafts declared table, calendar and kanban views on the resource (`viewModes`) with a switcher on the list page. That API is gone, and so are its view classes. A resource has its `screens`, and a board or a calendar is a block on a `BeakScreen`. The mapping is in [Upgrading](../start-here/upgrading.md).

## Rules and limits

| Rule | What happens |
| --- | --- |
| A board or a calendar loads up to 200 records of its model | Pass `filter:` to narrow them. When more match, a line beneath the block says how many are shown. Row policies on the server narrow what arrives too |
| Blocks load again after a write to their table | A board or a calendar queries again when a form, an action or another block writes its table. Only a colleague's write in another browser needs a `refreshPolicy` |
| The group field belongs to the block's model | Related fields throw when the board renders |
| Card and event text is the stored value | Enum columns show the enum name |
| A drop or a drag is one graph commit | The model's behavior and rules run. A refusal puts the card or event back, shows a toast and skips the callback |
| The timeline is read-only | Change the records in the table or the form |

## Verify it

The block tests build each block against a fake source, drop a card and drag an event. From `packages/beak_frontend`:

```console
$ flutter test test/src/blocks/beak_module_blocks_test.dart --name 'BeakKanbanBlock|BeakCalendarBlock|kanban' --reporter expanded
00:00 +0: BeakCalendarBlock maps records onto OiCalendar events
00:00 +1: BeakCalendarBlock a row without a start is left out, not given today
00:00 +2: BeakCalendarBlock a tap resolves back to the record; a drag persists
00:00 +3: BeakKanbanBlock one column per enum value, records grouped
00:00 +4: BeakKanbanBlock the group field must be an enum field of the block model
00:00 +5: BeakKanbanBlock dropping a card persists its new group
00:00 +6: module hardening (audit regressions) kanban fetches one full sorted page
00:00 +7: module hardening (audit regressions) a dropped kanban card stays in its new column
00:00 +8: module blocks read a filtered, bounded page kanban, calendar and chat send their filter
00:00 +9: All tests passed!
```

And the planner page renders in the showcase panel, from `examples/showcase`:

```console
$ flutter test test/aviary_pages_test.dart --name Planner --reporter expanded
00:00 +0: Planner renders
00:01 +1: All tests passed!
```

## Reference

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart:BeakKanbanBlockConstructor"
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become cards |
| `groupField` | `BeakScalarField<Enum>` | required | Enum field of `model` that defines the columns |
| `titleField` | `BeakColumn` | required | Card title |
| `subtitleField` | `BeakColumn?` | `null` | Card subtitle |
| `sortField` | `BeakColumn?` | `null` | Orders cards inside a column |
| `sortDescending` | `bool` | `false` | Direction of `sortField` |
| `label` | `String` | `Board` | Accessibility label |
| `onCardMove` | `void Function(BeakRecord)?` | `null` | Called after a drop the server accepted; a refused drop does not call it |
| `filter` | `BeakFilter?` | `null` | Narrows the records the board lists. It reads at most 200, and a note says when more match |

```dart title="packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart:BeakCalendarBlockConstructor"
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become events |
| `titleField` | `BeakColumn` | required | Event title |
| `startField` | `BeakColumn` | required | Event start |
| `endField` | `BeakColumn?` | `null` | Event end. Falls back to the start |
| `allDayField` | `BeakColumn?` | `null` | Boolean column marking all-day events |
| `categoryField` | `BeakColumn?` | `null` | An enum column tints events with its badge colors |
| `mode` | `OiCalendarMode` | `month` | Opening view: `day`, `week` or `month` |
| `label` | `String` | `Calendar` | Accessibility label |
| `onEventTap` | `void Function(BeakRecord)?` | `null` | Called with the tapped event's record |
| `onEventMove` | `void Function(BeakRecord, DateTime, DateTime)?` | `null` | Called after a drag the server accepted; a refused drag does not call it |
| `filter` | `BeakFilter?` | `null` | Narrows the records the calendar lists. It reads at most 200, and a note says when more match |

```dart title="packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart:BeakTimelineBlockConstructor"
```

| Parameter | Type | Meaning |
| --- | --- | --- |
| `query` | `BeakQuerySpec` | Produces one row per event |
| `titleField` | `BeakColumn` | Event title |
| `timeField` | `BeakColumn` | Event time. A record without one is left out |

Every block also takes `span`, its width in a grid. The remaining blocks are on [Data blocks](../blocks/data-blocks.md).

## Continue reading

- [Data blocks](../blocks/data-blocks.md): every block that reads a model, with the parameters of each.
- [A kanban view](../recipes/a-kanban-view.md): the board as a step-by-step recipe.
- [Custom screens](custom-screens.md): register a `BeakScreen` and get a route and a sidebar entry.
- [Actions](actions.md): model transitions with rules and receipts, for models a board cannot write to.
