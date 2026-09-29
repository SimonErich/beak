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

The board and the calendar write back: a dropped card and a dragged event update the record over its per-record route. That is convenient for plain models and rejected for models with business behavior, see [Writing from a view](#writing-from-a-view).

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

Every record becomes one event. `titleField` labels it, `startField` places it and `endField` closes it. Without an end the event ends where it starts, and a record with no start is placed at the current time. `allDayField` is a boolean column, and a `categoryField` that is an enum column tints each event with the badge color of its value. `mode` (`OiCalendarMode.day`, `week` or `month`) is the view it opens in, `month` by default.

Tapping an event calls `onEventTap` with the record. Dragging one writes the new start, and the new end when `endField` is set, and then calls `onEventMove`.

## The timeline

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:taskTimeline"
```

The timeline takes a whole `BeakQuerySpec`, so it is the one block here where you choose the filter, the sort and the page size yourself. Events are sorted newest first by `timeField`. It is read-only.

## Writing from a view

A dropped card or a dragged event is a single `PATCH` on that record. The server validates the changed value with the column's rules and applies the account's row and field policies, then saves it. When the save succeeds, the block mirrors it, so the card stays in its new column. When it fails, the card snaps back and nothing tells the user why. `onCardMove` and `onEventMove` run after the attempt either way, so treat them as "the user tried", not as "the write worked".

The server closes those per-record write routes for a model that declares `behavior`, is listed in `graphOnly` or takes part in validation rules that reach related tables. A drop on such a model is answered with `422` and `This resource must be saved through a graph commit.`, and the card returns. Model behavior and record rules only run in a graph commit, and a drag does not make one.

For a model with business transitions, use a table with model actions instead of a board. The action runs through the graph commit, gets its rules checked and leaves a receipt, see [Actions](actions.md). A board over such a model is fine for looking.

!!! note "Coming from viewModes"
    Earlier drafts declared table, calendar and kanban views on the resource (`viewModes`) with a switcher on the list page. That API is gone, and so are its view classes. A resource has its `screens`, and a board or a calendar is a block on a `BeakScreen`. The mapping is in [Upgrading](../start-here/upgrading.md).

## Rules and limits

| Rule | What happens |
| --- | --- |
| A block loads up to 500 records of its model | There is no `baseFilter` on the board or the calendar. Row policies on the server still narrow what arrives |
| Blocks load when they mount | A board or a calendar does not reload after a write made elsewhere. Leave and come back, or switch a tab. A `BeakTableBlock` does reload |
| The group field belongs to the block's model | Related fields throw when the board renders |
| Card and event text is the stored value | Enum columns show the enum name |
| A drop or a drag is one `PATCH` | Rejected for models with behavior, `graphOnly` models and rule-linked models |
| A failed write shows nothing | The card or event returns to where it was |
| The timeline is read-only | Change the records in the table or the form |

## Verify it

The block tests build each block against a fake source, drop a card and drag an event. From `packages/beak_frontend`:

```console
$ flutter test test/src/blocks/beak_module_blocks_test.dart --name 'BeakKanbanBlock|BeakCalendarBlock|kanban' --reporter expanded
00:00 +0: BeakCalendarBlock maps records onto OiCalendar events
00:00 +1: BeakCalendarBlock a tap resolves back to the record; a drag persists
00:00 +2: BeakKanbanBlock one column per enum value, records grouped
00:00 +3: BeakKanbanBlock the group field must be an enum field of the block model
00:00 +4: BeakKanbanBlock dropping a card persists its new group
00:00 +5: module hardening (audit regressions) kanban fetches one full sorted page
00:00 +6: module hardening (audit regressions) a dropped kanban card stays in its new column
00:00 +7: All tests passed!
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
| `onCardMove` | `void Function(BeakRecord)?` | `null` | Called after a drop, whether or not the write worked |

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
| `onEventMove` | `void Function(BeakRecord, DateTime, DateTime)?` | `null` | Called after a drag, whether or not the write worked |

```dart title="packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart:BeakTimelineBlockConstructor"
```

| Parameter | Type | Meaning |
| --- | --- | --- |
| `query` | `BeakQuerySpec` | Produces one row per event |
| `titleField` | `BeakColumn` | Event title |
| `timeField` | `BeakColumn` | Event time. A record without one is placed in 2026 |

Every block also takes `span`, its width in a grid. The remaining blocks are on [Data blocks](../blocks/data-blocks.md).

## Continue reading

- [Data blocks](../blocks/data-blocks.md): every block that reads a model, with the parameters of each.
- [A kanban view](../recipes/a-kanban-view.md): the board as a step-by-step recipe.
- [Custom screens](custom-screens.md): register a `BeakScreen` and get a route and a sidebar entry.
- [Actions](actions.md): model transitions with rules and receipts, for models a board cannot write to.
