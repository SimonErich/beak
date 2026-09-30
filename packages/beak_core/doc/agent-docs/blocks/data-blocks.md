# Data blocks

> Show live numbers, tables, timelines, boards and calendars on a custom screen, and learn what each block fetches, when it refreshes and where it stops.

A data block goes and fetches its own rows through the panel's data source, so a dashboard needs no view model and no repository code. After this page you can put a metric, a table, a timeline, a board or a calendar on a custom screen, and you know which of them refresh by themselves and where each stops.

## At a glance

| Block | Reads | Loading and error UI | Refreshes after a write |
| --- | --- | --- | --- |
| `BeakMetricBlock` | one aggregate (count, sum or average), plus one for `previous` | progress bar, error text with a retry button | yes |
| `BeakSummaryBlock` | one grouped summary ([Population summaries](summaries.md)) | spinner, error card with a retry button | yes |
| `BeakTableBlock` | pages of a model, server-side sort, filter and paging | as a resource list: a retryable error state | yes |
| `BeakTimelineBlock` | the query you pass | an error line with a retry button | yes |
| `BeakKanbanBlock` | the first 200 rows of a model, or of its `filter` | an error line with a retry button, and a toast when a move is refused | yes |
| `BeakCalendarBlock` | the first 200 rows of a model, or of its `filter` | an error line with a retry button, and a toast when a move is refused | yes |

"A write" means a confirmed save, delete or row action that went through the panel's data source. Every block above listens for it and fetches again. With a `refreshPolicy` on the panel, the same signal also fires on an interval and when the app returns to the foreground, so they refresh on a timer too.

Everything a data block asks for passes the same server checks as a list page: view permission, field access and row policy. A metric counts the rows that user may read, not the rows that exist. Soft-deleted rows are left out unless the spec says `withTrashed: true`.

## Metrics

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _metrics() => BeakGridBlock(
  minColumnWidthInPixels: 220,
  children: [
    BeakMetricBlock(
      label: 'Specimens',
      icon: OiIcons.bird,
      aggregate: const SpecimenModel().count(),
      target: 60,
    ),
    BeakMetricBlock(
      label: 'Endangered',
      icon: OiIcons.egg,
      aggregate: const SpecimenModel().count(
        filter: SpecimenModel.endangered.eq(true),
      ),
    ),
    BeakMetricBlock(
      label: 'Average weight',
      icon: OiIcons.feather,
      aggregate: const SpecimenModel().avg(SpecimenModel.weightInGrams),
      unit: 'g',
    ),
    BeakMetricBlock(
      label: 'Birds seen, second fortnight',
      icon: OiIcons.trees,
      aggregate: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.gte(AviaryDates.secondFortnightStart),
      ),
      previous: const SightingModel().sum(
        SightingModel.birdsSeen,
        filter: SightingModel.spottedOn.lt(AviaryDates.secondFortnightStart),
      ),
    ),
    BeakMetricBlock(
      label: 'Feed invoiced',
      icon: OiIcons.receiptText,
      aggregate: const InvoiceModel().sum(InvoiceModel.total),
      format: BeakValueFormat.currency,
    ),
  ],
);
```

The aggregate comes from the model: `const SpecimenModel().count()`, `.sum(field)` or `.avg(field)`, each with an optional `filter:`. Field and filter are generated references (`SpecimenModel.endangered.eq(true)`), so no column name is a string anywhere.

- `target` draws a progress track under the value and labels it `value / target`. The Aviary has to reach 60 specimens.
- `previous` takes a second aggregate, usually the same sum over the earlier period, and shows the change as a signed percentage next to a trend arrow: `(value - previous) / |previous|`. Nothing shows while `previous` is 0. The color follows the sign, the theme's success color for up and its error color for down, so a falling error count is drawn as bad news.
- `unit` follows the value and the target with a space: `'g'` renders `880.86 g` under the Aviary's formatting. `format` is `number` (the default), `currency` or `percent`, and nothing else is accepted. Numbers go through the panel's [formatting policy](../theming/formatting-and-localization.md), so the same block prints `1.234,50` under `de_DE` and `1,234.50` under `en_US`.
- `minorUnits: true` turns stored integer cents into major units before display (`scale`, default 2, says how many places). An aggregate always returns storage units, so a sum over an integer cents column needs it.

Money is where the typed helpers stop. `sum` and `avg` take numeric fields of the model itself, `int` or `double`. An exact `BeakDecimal` field has an imperative `field.sum(source)` that returns a `BeakDecimal`, but nothing that builds an aggregate spec for a block. For a metric over money, keep the amount as integer minor units (Foodio's `grossCents`), which sum exactly. A `double` decimal column also works (the Aviary's invoice `total`), with a double's rounding.

## Tables

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _upcomingTasks() => BeakCardBlock(
  title: 'Upcoming tasks',
  child: BeakTableBlock(
    model: const TaskModel(),
    fields: [
      TaskModel.title,
      TaskModel.category,
      TaskModel.status,
      TaskModel.startsAt,
    ],
    enableDelete: false,
    initialSpec: const TaskModel().query(
      sorts: [TaskModel.startsAt.ascending()],
      pagination: const BeakPagination(perPage: 5),
    ),
    baseFilter: TaskModel.status.notEq(TaskStatus.done),
  ),
);
```

`BeakTableBlock` is the resource list's table in a box: the same `BeakDataTable`, the same server-side sorting, filtering and paging, the same cell rendering, so a badge or a date looks exactly as it does on the list page. What you decide:

- `fields` lists the columns as generated field references, in order. It takes precedence over `columns` (a list of `BeakColumn`) and switches off the automatic relationship columns. Without either, you get the model's table columns.
- `initialSpec` seeds the first sort order and page size. Here: soonest first, five rows.
- `baseFilter` is merged into every query the table runs. The reader can still sort, filter and page inside your scope, but never out of it.
- `enableDelete` defaults to `true` and adds a delete action with undo to every row. On a dashboard, that is rarely what you want. Set it to `false` for read-only listings.
- `actions` adds row actions, `onRowTap` receives the tapped `BeakRecord`. A tap does nothing unless you pass `onRowTap`, and a block with a callback cannot be `const`.
- `heightInPixels` (360) bounds the table. Layout blocks do not, and a table needs a height.
- `title` wraps the table in a card with that heading. The example uses a `BeakCardBlock` instead, so the title sits with the other cards.

## Timelines

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _taskTimeline() => BeakCardBlock(
  title: 'Recent tasks',
  child: BeakTimelineBlock(
    query: const TaskModel().query(
      sorts: [TaskModel.startsAt.descending()],
      pagination: const BeakPagination(perPage: 8),
    ),
    titleField: TaskModel.title.column,
    timeField: TaskModel.startsAt.column,
  ),
);
```

Each row becomes an event, titled by `titleField` and placed by `timeField`. A row with no readable time has no place on a timeline and is left out. The block sorts newest first itself, whatever order the query used, so the query's `sorts` only decides which rows make the cut when there are more than `perPage`. That is the timeline's one lever: it shows exactly the rows your query returns, eight here.

## Boards and calendars

The Aviary shows the same chores twice, as a board and as a calendar. Both blocks take a `model` instead of a query and read its rows, up to 200 (`BeakPagination.maxPerPage`), or the rows of a `filter:` you pass:

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

`framed: false` is deliberate. A board and a calendar fill the height the panel gives them, so they skip the standard page frame and its scrolling.

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

The board makes one column per value of `groupField`, which must be an enum field of the model itself (anything else throws a `BeakConfigurationException` when the board builds). Columns come in the enum's declaration order, with each value's label and badge color. `titleField`, `subtitleField` and `sortField` are columns (`TaskModel.title.column`), and `sortField` orders the cards inside each column.

```dart title="examples/showcase/lib/pages/data_blocks.dart"
BeakBlock _calendar() => BeakCalendarBlock(
  model: const TaskModel(),
  titleField: TaskModel.title.column,
  startField: TaskModel.startsAt.column,
  endField: TaskModel.endsAt.column,
  allDayField: TaskModel.allDay.column,
  categoryField: TaskModel.category.column,
  label: 'Chore calendar',
);
```

The calendar places each row by `startField` and `endField` (an event without an end lasts as long as its start), flags all-day rows with `allDayField`, and tints an event with the badge color of `categoryField` when that column is an enum. `mode` picks the first view, `OiCalendarMode.month` by default.

A calendar row with no readable start has no place on the calendar and is left out.

Both blocks write. Drop a card in another column and the block saves the new value of `groupField`. Drag an event and it saves the new start, and the new end when `endField` is bound. Each is one update through the panel's data source, which sends it as a graph commit, so a model that only accepts graph commits (`graphOnly`) can be moved too. The card or event stays where you dropped it once the save succeeds. Three things to know before you rely on it:

- A refused move shows the reason in a toast (the server's message for a validation or permission failure, a generic line for an infrastructure one) and the item snaps back.
- `onCardMove` and `onEventMove` are called once per confirmed move, with the record as it was before the move (and, for an event, the start and end that were written). A refused move does not call them. A card dropped in its own column writes nothing and calls nothing.
- `filter:` narrows what the block lists. A model with more matching rows than the page holds shows only the first 200, and a line beneath the block says so (`Showing the first 200 of 340.`). A chat, inbox, pricing, FAQ or file manager block takes the same `filter:` and gives the same notice.

## Rules and limits

- Fetching blocks need the panel. They read `beakDependencies(context)<BeakDataSource>()`. Outside a `BeakPanel`, provide that scope yourself ([Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md)).
- 200 rows, no more. Kanban, calendar, chat, inbox, pricing, FAQ and the file manager read one page of at most 200 (`BeakPagination.maxPerPage`, what the server answers with). More matching rows are not there, and a line beneath the block says how many are shown. The default page of a plain query is 25, which is why the Aviary's chart queries ask for the largest page themselves ([Charts](charts.md)).
- A failed read is shown. The metric replaces its number with the error text and a Retry button, the summary with an error card, the table with its error state. The timeline, the board and the calendar keep what they drew before, put the panel's error line above it and offer Retry. None of them draws an empty block as if the data were empty. A block that has not loaded anything yet stays empty under the error line.
- Undated rows are left out. A timeline row without a readable time and a calendar row without a readable start are not drawn. No date is invented for them.
- Times follow the panel's zone. The calendar and the timeline show a stored instant in the panel's `formatting` zone (device time by default, or `timeZoneOffsetMinutes`), and a dragged event is written back as the instant that wall-clock time names in that zone, so a drag never shifts the hour.
- Aggregates are storage units. `avg` comes back with its fraction (880.857... above) and rounding is the display's job.
- Metrics are separate requests. A metric with `previous` sends two. A page with twelve metrics sends twelve, each on its own, and refreshes each after a write to its table.
- Sort and page inside `initialSpec` are a start. The reader can change both in a table block. Put permanent scoping in `baseFilter`.

## Verify it

Run the Aviary's page tests, which build every data block against a fixture source:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
Data blocks renders
...
All tests passed!
```

The fixture source cannot answer aggregates, so this proves the page builds and not that the numbers are right. For the numbers, start the Aviary API as its README describes (`dart run bin/serve.dart`, port 8082) and ask it what a metric asks:

```console
$ curl -s -X POST localhost:8082/api/tasks/aggregate \
    -H 'content-type: application/json' -d '{"table":"tasks","function":"count"}'
{"value":12}
$ curl -s -X POST localhost:8082/api/specimens/aggregate \
    -H 'content-type: application/json' -d '{"table":"specimens","function":"avg","column":"weight_in_grams"}'
{"value":880.8571428571429}
```

The second is the "Average weight" metric before formatting. The panel shows it as `880.86 g`.

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakMetricBlock` | `label`*, `aggregate`*, `icon`, `format` (`BeakValueFormat.number`), `minorUnits` (false), `scale` (2), `unit`, `previous`, `target` |
| `BeakTableBlock` | `model`*, `title`, `columns`, `fields`, `enableDelete` (true), `initialSpec`, `baseFilter`, `actions` (empty), `onRowTap`, `heightInPixels` (360) |
| `BeakTimelineBlock` | `query`*, `titleField`*, `timeField`* |
| `BeakKanbanBlock` | `model`*, `groupField`*, `titleField`*, `subtitleField`, `sortField`, `sortDescending` (false), `label` (`'Board'`), `onCardMove`, `filter` |
| `BeakCalendarBlock` | `model`*, `titleField`*, `startField`*, `endField`, `allDayField`, `categoryField`, `mode` (`OiCalendarMode.month`), `label` (`'Calendar'`), `onEventTap`, `onEventMove`, `filter` |

The two fetching constructors with the most parameters, verbatim:

```dart title="packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
const BeakMetricBlock({
  required this.label,
  required this.aggregate,
  this.icon,
  this.format = BeakValueFormat.number,
  this.minorUnits = false,
  this.scale = 2,
  this.unit,
  this.previous,
  this.target,
  super.span,
}) : assert(scale >= 0 && scale <= 12, 'scale must be between 0 and 12'),
     assert(
       format == BeakValueFormat.number ||
           format == BeakValueFormat.currency ||
           format == BeakValueFormat.percent,
       'format must be number, currency or percent',
     );
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_table_block.dart"
const BeakTableBlock({
  required this.model,
  this.title,
  this.columns,
  this.fields,
  this.enableDelete = true,
  this.initialSpec,
  this.baseFilter,
  this.actions = const [],
  this.onRowTap,
  this.heightInPixels = 360,
  super.span,
});
```

Every block class with its constructor is on [Blocks](../reference/blocks.md). The metric's state handling is walked through in [Block system internals](../architecture/block-system-internals.md).

## Continue reading

- [Population summaries](summaries.md) grouped totals, donuts, bars and capacity tracks over the full population.
- [Charts](charts.md) draw your own query as a line, bar, pie or heat map.
- [Dashboards](../panel/dashboards.md) how these blocks add up to an overview page.
- [Module blocks](module-blocks.md) chat, inbox, files, invoices and the other data-bound views.
