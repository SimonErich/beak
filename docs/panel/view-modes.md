---
title: View modes
description: Give a resource's list page a calendar or a board alongside the table with BeakResourceView, declared in lib/resources/<table>.dart, and see how view modes differ from the placeable data blocks.
---

# View modes

After this page you can add extra presentations (a calendar, a Kanban board) to a
resource's list page from typed configuration, and you will know how these list
view-modes differ from the same-named blocks you can drop anywhere.

## One list, several presentations

Every resource starts with a table view. Declare more than one `BeakResourceView`
and Beak puts an `OiSegmentedControl` above the list so the user switches between
them. A view mode is a sealed type that builds a `BeakBlock` from the resource's
model, so it is pure typed configuration, not a hand-written widget.

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_view.dart"
sealed class BeakResourceView {
  /// Enables `const` subclasses.
  const BeakResourceView();

  /// Stable identifier of this mode, unique within a resource.
  String get key;

  /// The label shown on the mode's segmented-control segment.
  String get label;

  /// The icon shown on the mode's segmented-control segment.
  IconData get icon;

  /// Builds the block that renders [model]'s records in this mode.
  BeakBlock build(BeakModel model);
}
```

There are three subclasses.

### BeakTableView

The default, and the one you already get. It renders the resource's records in the
data table. It optionally seeds the first query and carries a base scope:

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_view.dart"
const BeakTableView({this.initialSpec, this.baseFilter});
```

`initialSpec` seeds sort order and page size on first load; `baseFilter` is a
predicate AND-merged into every query. Both are passed to the `BeakTableBlock`
this view builds. A resource's list page renders its own table rather than that
block, seeded from the filter bar, so on a list page `const BeakTableView()` is
all you write. See [Tables and filters](tables-and-filters.md).

### BeakCalendarView

Lays the records out as scheduled events, bound to your date and title columns:

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_view.dart"
const BeakCalendarView({
  required this.titleField,
  required this.startField,
  this.endField,
  this.allDayField,
  this.categoryField,
  this.mode = OiCalendarMode.month,
  this.label = 'Calendar',
});
```

| Field | Type | What it supplies |
| --- | --- | --- |
| `titleField` | `BeakColumn` | Each event's title. |
| `startField` | `BeakColumn` | Each event's start instant. |
| `endField` | `BeakColumn?` | Each event's end instant, when bound. |
| `allDayField` | `BeakColumn?` | A boolean flag for all-day events. |
| `categoryField` | `BeakColumn?` | Categorizes and colors events. |
| `mode` | `OiCalendarMode` | The initial calendar mode (`month` by default). |
| `label` | `String` | The segmented-control label (`'Calendar'` by default). |

### BeakKanbanView

Groups the records into board columns by an enum field:

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_view.dart"
const BeakKanbanView({
  required this.groupField,
  required this.titleField,
  this.subtitleField,
  this.sortField,
  this.sortDescending = false,
  this.label = 'Board',
});
```

`groupField` is typed as `BeakEnumColumn<Enum>`, not any column: the board's
columns are exactly the enum's values, so the framework knows every lane up front
and you cannot point it at something that has no fixed set of buckets. `titleField`
labels each card; `subtitleField` and `sortField` are optional.

## Declaring the switcher

View modes are one of the things a schema class cannot decide for you, so they go
in `lib/resources/<table>.dart`, the per-resource file that takes the generated
resource and returns an adjusted copy. The store gives products a table and a
board grouped by status:

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  // ... record and bulk actions ...
  viewModes: const [
    BeakTableView(),
    BeakKanbanView(
      groupField: ProductColumns.status,
      titleField: ProductColumns.name,
      subtitleField: ProductColumns.sku,
    ),
  ],
);
```

The superdashboard gives orders the same treatment, sorted newest first, beside
its declared filters:

```dart title="examples/superdashboard/lib/resources/orders.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: orderLayout,
  formLayout: orderLayout,
  filters: [
    const BeakSelectFilter(column: OrderColumns.status, label: 'Status'),
    const BeakSelectFilter(column: OrderColumns.source, label: 'Source'),
  ],
  viewModes: [
    const BeakTableView(),
    const BeakKanbanView(
      groupField: OrderColumns.status,
      titleField: OrderColumns.reference,
      subtitleField: OrderColumns.total,
      sortField: OrderColumns.placedAt,
      sortDescending: true,
    ),
  ],
);
```

and gives calendar events a month calendar:

```dart title="examples/superdashboard/lib/resources/calendar_events.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: calendarEventDetail,
  formSteps: calendarEventFormSteps,
  viewModes: [
    const BeakTableView(),
    const BeakCalendarView(
      titleField: CalendarEventColumns.title,
      startField: CalendarEventColumns.startAt,
      endField: CalendarEventColumns.endAt,
      allDayField: CalendarEventColumns.allDay,
    ),
  ],
);
```

Nothing in those files names the model, the icon, the label, or the section. Those
still come from the schema class and `beak.yaml`, and `beak prepare` wraps the
generated resource in your function. Run `beak eject resource <table>` to start
one; it returns `generated` unchanged until your first edit. See
[Resources](resources.md).

Once declared, the list page reads `viewModes.length`: one mode renders the table
bare, more than one renders an `OiSegmentedControl` whose segments come from each
mode's `label` and `icon`, with the selected mode's block beneath it.

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
Expanded(
  child: switch (current) {
    BeakTableView() => table,
    _ => BeakBlockHost(block: current.build(model)),
  },
),
```

## View modes are not the same as blocks

This is the one thing to keep straight. A `BeakCalendarView` builds a
`BeakCalendarBlock`, and a `BeakKanbanView` builds a `BeakKanbanBlock` (you can
see it in each view's `build`). But the view and the block are not
interchangeable, and they live in different places.

!!! warning "Two calendars, two Kanbans"
    - **View modes** (`BeakCalendarView`, `BeakKanbanView`) are list-page
      presentations. They belong on a resource's `viewModes`, they take a
      segmented-control segment, and they render *that resource's* records. You
      cannot place a view mode anywhere else.
    - **Blocks** (`BeakCalendarBlock`, `BeakKanbanBlock`) are placeable anywhere
      a block tree goes: a dashboard, a custom screen, a card in a detail layout.
      They bind to any model you name, independent of any resource's list page.

    The view modes wrap the blocks so a resource can offer a calendar without you
    composing a block tree. When you want that calendar or board *off* the list
    page, reach for the block directly. See
    [Data blocks](../blocks/data-blocks.md).

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_view.dart"
@override
BeakBlock build(BeakModel model) => BeakCalendarBlock(
  model: model,
  titleField: titleField,
  startField: startField,
  endField: endField,
  allDayField: allDayField,
  categoryField: categoryField,
  mode: mode,
  label: label,
);
```

!!! note "What just happened"
    - A `lib/resources/<table>.dart` returned `generated.copyWith(viewModes: …)`,
      and the list grew a segmented switcher.
    - Each non-table mode built a data block from the model and handed it to
      `BeakBlockHost` to render.
    - The block did the drawing; the view mode was the typed configuration that
      chose the block and its fields.

## Continue reading

- [Tables and filters](tables-and-filters.md) the default view mode and the query
  spec every mode shares.
- [Data blocks](../blocks/data-blocks.md) the placeable `BeakCalendarBlock` and
  `BeakKanbanBlock` behind these view modes.
- [Resources](resources.md) the file `viewModes` is declared in, and what else it
  can change.
- [beak.yaml](../reference/beak-yaml.md) the icon, label, and section a resource
  keeps taking from the project file.
