---
title: Data blocks
description: KPI tiles, metric cards, data tables, calendars, and kanban boards that resolve a BeakDataSource and fetch their own rows.
---

# Data blocks

After this page you can drop a live KPI tile, a metric card, a data table, a
calendar, or a kanban board onto any block surface. Each one names a model or an
aggregate and fetches its own rows at render time, so nothing on the page is
hardcoded.

## What makes a block "data-bound"

A layout or display block is inert configuration: it draws whatever you hand it.
A data block is different. It carries a model (or a `BeakAggregateSpec`) and,
when the host renders it, it resolves the panel's data source and asks for the
numbers itself:

```dart title="packages/beak_frontend/lib/src/blocks/views/beak_kpi_block_view.dart"
final dataSource = beakLocator<BeakDataSource>();
// ...
final loaded = await dataSource.aggregate(block.value);
```

That `beakLocator<BeakDataSource>()` is the package-scoped GetIt lookup Beak
wires when the panel boots. In the running app it resolves to
`HttpBeakDataSource` over REST; in a test it resolves to whatever fake you
registered (`InMemoryBeakDataSource` from `package:beak/testing.dart`). Either
way the block is the same `const` descriptor. The five blocks below are the
data-bound ones you place by hand; the [chart](../charts/chart-basics.md) and
[map](../charts/maps.md) blocks work the same way.

You place them wherever a block tree goes: `lib/dashboard.dart` for the home
screen, `lib/screens/<name>.dart` for a page of your own, or a card inside
either.

| Block | Binds to | Fetches |
| --- | --- | --- |
| `BeakKpiBlock` | one (or two) `BeakAggregateSpec` | a headline number and a delta |
| `BeakMetricBlock` | one `BeakAggregateSpec` | a single count or sum |
| `BeakTableBlock` | a `BeakModel` | a paged, sortable, filterable list |
| `BeakCalendarBlock` | a `BeakModel` + field bindings | records as scheduled events |
| `BeakKanbanBlock` | a `BeakModel` grouped by an enum column | records as draggable cards |

## KPI tiles

`BeakKpiBlock` is a headline aggregate with an optional prior-period aggregate
that drives an up/down delta badge, plus an optional target track.

```dart title="packages/beak_frontend/lib/src/blocks/beak_kpi_block.dart"
const BeakKpiBlock({
  required this.title,
  required this.value,
  this.previous,
  this.target,
  this.format = BeakKpiFormat.number,
  this.currencySymbol = r'$',
  this.decimals = 0,
  super.span,
});
```

The showcase dashboard opens with four of them: an earnings sum and three counts.

```dart title="examples/superdashboard/lib/dashboard.dart"
--8<-- "examples/superdashboard/lib/dashboard.dart:kpis"
```

!!! note "What just happened"
    - `count`, `sum` and `avg` are all `const` constructors, so the whole grid
      is one `const` expression. The API computes every figure; the browser
      receives a number, not a table to count.
    - `OrderColumns.total` is generated from the `total` field of the `Order`
      schema class. Rename the field and this file stops compiling, which is
      the point.
    - `format: BeakKpiFormat.currency` turns the raw number into `$34,123` using
      `currencySymbol`. The two other formats are below.

`format` picks how the value and delta read:

| `BeakKpiFormat` | Renders |
| --- | --- |
| `number` | a grouped integer (`34,123`) |
| `currency` | the same, prefixed with `currencySymbol` (`$34,123`) |
| `percent` | the value times 100 with a `%` suffix |

## Metric cards

`BeakMetricBlock` is the compact single-number cousin: the composable form of a
dashboard stat, no delta badge. Use it when you want one count or sum in a card,
optionally wrapped in a prefix or suffix.

```dart title="packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
const BeakMetricBlock({
  required this.label,
  required this.aggregate,
  this.icon,
  this.prefix = '',
  this.suffix = '',
  super.span,
});
```

The block's own dartdoc shows the shape a call takes:

```dart
BeakMetricBlock(
  label: 'Products',
  aggregate: BeakAggregateSpec.count(table: 'products'),
  icon: OiIcons.package,
);
```

## Data tables

`BeakTableBlock` embeds the full `BeakDataTable` (the same widget a resource list
page uses) inside a page or a card. You get server-side sort, filter, and
pagination for free; `initialSpec` seeds the ordering and page size,
`baseFilter` scopes the rows, and `columns` narrows what is shown.

```dart title="packages/beak_frontend/lib/src/blocks/beak_table_block.dart"
const BeakTableBlock({
  required this.model,
  this.title,
  this.columns,
  this.initialSpec,
  this.baseFilter,
  this.actions = const [],
  this.onRowTap,
  this.heightInPixels = 360,
  super.span,
});
```

The dashboard's three listings are all the same block over different models:

```dart title="examples/superdashboard/lib/dashboard.dart"
BeakBlock _tables() => const BeakGridBlock(
  columns: 12,
  children: [
    BeakTableBlock(
      span: BeakSpan(columns: 6),
      title: 'Latest orders',
      model: OrderModel(),
      initialSpec: BeakQuerySpec(
        table: 'orders',
        sorts: [BeakSort('placed_at', descending: true)],
        pagination: BeakPagination(perPage: 6),
      ),
    ),
    // ... Top customers (UserModel) and Latest transactions (TransactionModel).
  ],
);
```

### Narrowing the columns

Leave `columns` unset and the table shows the model's table-context columns,
which is what a list page wants and what a dashboard card cannot fit. Pass a
list of generated column constants and the card shows those, in that order. The
store's dashboard does exactly this for its two lists:

```dart title="examples/store/lib/dashboard.dart"
BeakCardBlock(
  span: BeakSpan(columns: 6),
  title: 'Latest orders',
  child: BeakTableBlock(
    model: OrderModel(),
    columns: [
      OrderColumns.reference,
      OrderColumns.status,
      OrderColumns.total,
    ],
    initialSpec: BeakQuerySpec(
      table: 'orders',
      sorts: [BeakSort('placed_at', descending: true)],
      pagination: BeakPagination(perPage: 5),
    ),
  ),
),
```

!!! note "What just happened"
    - Three columns read at a glance where seventeen do not fit at all. The
      resource's own list page still shows everything.
    - `columns` takes `BeakColumn` constants generated from the `Order` schema
      class, never key strings.
    - `baseFilter` is the other narrowing knob: the store's second card scopes
      products to `featured == true` with a `BeakFieldFilter` while leaving the
      user's own sorting and paging alone.

!!! tip "heightInPixels earns its keep"
    A table needs a vertical bound to lay out, and a grid cell or card gives it
    none. `heightInPixels` (default `360`) is that bound. If a table block
    renders blank inside a card, this is usually why.

!!! note "One column per to-one relationship, free"
    A list table already renders a column for each to-one relationship, showing
    the related record's name rather than its foreign key, loaded with the page
    in a single query. You do not add it and you do not pay an extra request
    for it.

## Calendars and kanban boards

`BeakCalendarBlock` renders a model's records as events on an `OiCalendar`, and
`BeakKanbanBlock` renders them as cards on an `OiKanban`, one column per enum
value. Both bind fields by typed `BeakColumn`, not by string, and both persist
drags back through `dataSource.update`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart"
const BeakCalendarBlock({
  required this.model,
  required this.titleField,
  required this.startField,
  this.endField,
  this.allDayField,
  this.categoryField,
  this.mode = OiCalendarMode.month,
  this.label = 'Calendar',
  this.onEventTap,
  this.onEventMove,
  super.span,
});
```

A calendar over an events model reads like this:

```dart
BeakCalendarBlock(
  model: const EventModel(),
  titleField: EventColumns.title,
  startField: EventColumns.startsAt,
  endField: EventColumns.endsAt,
  categoryField: EventColumns.status,
  onEventTap: (record) => print(record[EventColumns.title.key]?.raw),
);
```

The kanban board takes its columns straight from an enum column's declared
values, so the swimlanes are never stringly-typed. Note that `groupField` is a
`BeakEnumColumn`, not a plain `BeakColumn`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
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
```

And a board over a tasks model:

```dart
BeakKanbanBlock(
  model: const TaskModel(),
  groupField: TaskColumns.status, // a BeakEnumColumn
  titleField: TaskColumns.title,
  subtitleField: TaskColumns.assignee,
  onCardMove: (record) => print('moved ${record[TaskColumns.id.key]?.raw}'),
);
```

!!! warning "Blocks, not view modes"
    `BeakCalendarBlock` and `BeakKanbanBlock` are blocks you place anywhere a
    block tree goes: a custom screen, a card, an overlay. They are a different
    thing from `BeakCalendarView` and `BeakKanbanView`, which are alternate
    **view modes** you attach to a resource so its list page can toggle between
    a table, a calendar, and a board. View modes are set on the resource, in
    `lib/resources/<table>.dart`:

    ```dart title="examples/superdashboard/lib/resources/orders.dart"
    BeakResource beakResource(BeakResource generated) => generated.copyWith(
      // ... detail, formLayout and filters, then:
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

    Same obers_ui widget underneath, two ways to reach it. See
    [View modes](../panel/view-modes.md) for the resource-level pair.

## Continue reading

- [Dashboards](../panel/dashboards.md) how the config-driven dashboard composes KPI, chart, and table blocks.
- [View modes](../panel/view-modes.md) the resource-level `BeakCalendarView` and `BeakKanbanView` these blocks mirror.
- [Chart basics](../charts/chart-basics.md) the other data-bound block: `BeakChartBlock` and its mappers.
- [Record blocks](record-blocks.md) the dual-mode blocks that bind to a single record instead of a query.
