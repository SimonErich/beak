---
title: Population summaries
description: Declare grouped, filtered totals that the server computes over the whole authorized population and show them as metrics, bars, donuts or capacity tracks.
type: guide
audience: [expert]
status: stable
---

# Population summaries

A table shows one page of rows, so any total computed from that page is wrong the moment there is a second page. A summary asks the server instead: it groups and counts the whole population the user may see, and the block draws the answer. After this page you can declare measures, pick one of six presentations, scope a summary to a composed list, and read the request it sends.

## At a glance

A summary has four parts, and two of them are objects you declare once and reuse:

| Part | What it is | Declared with |
| --- | --- | --- |
| Measure | One named number per group: a count, or a sum of a numeric or exact-decimal field, optionally filtered. | `BeakSummaryMeasure.count`, `BeakSummaryMeasure.sum`, `BeakSummaryMeasure.sumDecimal` |
| Spec | Table, optional `groupBy`, 1 to 8 measures, filter, search, group `limit`. | `model.summary(...)` |
| Value | How one measure is labeled and formatted on screen. | `BeakSummaryValue(measure:, label:)` |
| Block | The spec, the values and a presentation. | `BeakSummaryBlock` |

Measures are matched by object, not by key. You read a number back with `row.valueOf(measure)`, and a value, a capacity pair or a footer binds to the same measure object you put in the spec. The `key` string only names the number on the wire.

| `presentation` | Draws | Needs |
| --- | --- | --- |
| `metrics` (default) | One caption and number per group and value. | nothing |
| `strip` | A row of labeled values without a card heading. | an ungrouped spec, normally |
| `bar` | Grouped bars, one series per value. | `groupBy` |
| `donut` | One measure split across groups, or one segment per measure when ungrouped. | nothing |
| `table` | One line per group with every value. | nothing |
| `capacity` | A used-against-total track per group. | `capacity:`, and normally a `groupBy` |

## Measures and one summary

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryMeasures"
```

`count` is `const`. `sum` is not, because it takes a generated field and reads its key at runtime. A measure can carry a `filter:` (the `done` measure counts only finished tasks), and its population is the intersection of that filter, the summary's own filter and the row scope the user is authorized for. Here is the Aviary's donut over them:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryDonut"
```

`groupBy: TaskModel.status` also decides how each group is named. The block looks the field up in the model registry, so the segments carry the enum's labels and a date column would use the panel's date pattern. You declare the grouping once.

## The six presentations

### Bar, with a table toggle

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryBar"
```

Two values make two series. `showTableToggle: true` adds a small switch to the card header that shows the same loaded result as text rows, so no second request is made. `showValues` prints the numbers above the bars, `maximum` and `divisions` fix the value axis, and `heightInPixels` (240) sets the chart height.

### Capacity

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryCapacity"
```

A capacity summary compares two measures per group, `used` against `total`, on a track. The pair is objects from the spec, never key strings. The track turns to a warning at `warningThreshold` (default `.95`), and `warning` can turn the row into a sentence. Foodio does that for its delivery slots:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioSlotMeasures"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioSlotCapacity"
```

The displayed quantities stay authoritative when a slot is overbooked: the track clamps at full, the numbers do not.

### Strip, table and metrics

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryStrip"
```

The strip is the compact one. It draws no card heading (the title stays as its accessible label), wraps into fewer columns as space narrows, and ignores `subtitle`, `legend`, `footer` and the table toggle. `BeakSummaryValue` gives each entry an `icon` and an `iconColor`, a `BeakColor` that the theme resolves. It is what Foodio uses as the `collapsedHeader` of its order list, shown when the charts are hidden.

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryTable"
```

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:summaryMetrics"
```

`table` is text, not a table widget: one line per group, the group's name followed by `Tasks: 3` and `Done: 1`. `metrics` is what you get without a `presentation`: a caption and a number per value, and for a grouped summary one per group and value.

## Conditional measures

A measure with a `filter` lets one query count populations that overlap or that no status column expresses. Foodio splits today's orders into mutually exclusive operational states without adding a column:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioStatusValues"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioStatusDonut"
```

An ungrouped donut draws one segment per value, in the value's own `color`, and `centerLabel` puts their total in the middle. Overlapping populations therefore add up to more than the number of distinct records, so do not caption the total "orders" when a record can fall in two segments. Foodio's measures are exclusive on purpose (a status, and `needsAttention` false), plus one segment for the attention cases.

## Groups: order, style, legend, footer

Foodio's daily bar chart uses everything at once:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioDayMeasures"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioDailyBars"
```

- `groupStyle` maps each `BeakSummaryRow` to a `BeakSummaryGroupStyle`: a short `label` (the day number), a second-level `section` (the calendar week), a `color`, `hatched` for planned quantities and `emphasized` for the current group. It changes the picture and never a number.
- `legend` takes `BeakSummaryLegend` entries, so a hatched bar has a key that says "Scheduled".
- `footer` receives the whole `BeakSummaryResult` and returns a sentence, computed from the full population and not the visible page.
- `groupOrder` lists raw group values in display order (for an enum, the stored names such as `TaskStatus.todo.name`). Groups it does not name come after. Without it, groups come back sorted by stored value: a `null` group first, numbers ascending, everything else alphabetically. That means `doing`, `done`, `todo` for the task statuses, not their declaration order.

## Inside a composed list

A summary in a composed list's `header` or `collapsedHeader` shares the list's query. The `scope` says how much of it:

| `scope` | Inherits from the list | Use it for |
| --- | --- | --- |
| `active` (default) | permanent scope, selected preset, filters and search; never sorting or paging | totals that follow what the reader filters |
| `base` | the permanent query only | totals that stay put while the reader filters |
| `standalone` | nothing, the block's own query | a different model, or a fixed cohort |

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListOverview"
```

Foodio's compact overview uses `base`, so "orders today" does not change when a filter chip does:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioCompactOverview"
```

Under `active` and `base` the list's filter, search and trashed flag replace the summary's own. A `filter:` you put on the spec is dropped, and only the measure filters survive. Put your own scoping in measure filters, or use `standalone`. A summary over a different table than the list must be `standalone`, because the block refuses to merge two tables and throws a `BeakConfigurationException` when it builds. Outside a list there is nothing to inherit and the scope does not matter. Paging the list's table never changes a summary. Refreshing after a write does: the block fetches again whenever its table changes.

## The request behind it

`BeakClient.summary(spec)` posts the spec to `POST /api/{table}/summary`. The Aviary API answers the "Tasks by status" donut like this:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":"status","measures":[{"key":"tasks","column":null}],"limit":100}'
{"rows":[{"group":"doing","values":{"tasks":2}},{"group":"done","values":{"tasks":4}},{"group":"todo","values":{"tasks":6}}],"truncated":false}
```

An ungrouped spec with a filtered measure answers with one row whose `group` is `null`:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":null,"measures":[{"key":"tasks","column":null},{"key":"done","column":null,"filter":{"type":"field","column":"status","operator":"eq","value":"done"}}],"limit":100}'
{"rows":[{"group":null,"values":{"tasks":12,"done":4}}],"truncated":false}
```

When there are more groups than `limit`, the response keeps the first ones and says so:

```console
$ curl -s -X POST localhost:8082/api/tasks/summary -H 'content-type: application/json' \
    -d '{"table":"tasks","groupBy":"status","measures":[{"key":"tasks","column":null}],"limit":2}'
{"rows":[{"group":"doing","values":{"tasks":2}},{"group":"done","values":{"tasks":4}}],"truncated":true}
```

The block turns `truncated` into a line above the chart: "Only the first groups are shown. Narrow the filters to see every group."

## Rules and limits

- **Authorization is the server's.** Before it computes anything, the server checks view permission on the table, read access to the grouping field and to every summed field, and every field named in the spec's filter or a measure's filter, relationship paths included. Row policy and soft-delete scope are added to the shared population, so they apply to every measure. A summary can never count a row a list would not show.
- **Which sources can answer.** `WormDataSource` computes summaries, and the panel's HTTP source forwards to it. The in-memory source in `beak_test` and the Serverpod bridge do not implement `BeakSummaryDataSource`, so a summary over them shows an error card with a Retry button and the panel's generic sentence ("The operation could not be completed."): the source's own "does not support summaries" message is a configuration failure, and the panel never prints those. In tests, give your fake source the interface, as the package tests do.
- **Bounds.** 1 to 8 measures with unique keys of at most 80 characters, and a `limit` from 1 to 500 (default 100). Outside those, the spec constructor throws a `BeakConfigurationException` and a hand-written request gets a 422.
- **Summed fields are numeric root fields.** `BeakSummaryMeasure.sum` takes an `int` or `double` field of the summarized model. `BeakSummaryMeasure.sumDecimal` takes a `BeakDecimal` (money or exact-decimal) field and adds its stored integer units on the server, which is exact. A field reached through a relationship is rejected when the measure is built, and a text field does not type-check. In code, `row.decimalOf(measure)` reads a decimal sum back as a `BeakDecimal`. A summary block shows the number `valueOf` returns, which for a decimal sum is a count of minor units, so give its value `minorUnits: true` and the field's `scale`.
- **Group by scalars and dates, not instants.** A date column groups by calendar date. A timestamp column groups by exact instant, which gives one group per distinct timestamp, and the API never buckets instants in a guessed timezone. Group by the date column, or by an enum. JSON and custom columns cannot be grouped, and neither can a related field.
- **`groupBy` and filters differ on relationships.** The grouping field must belong to the model. A filter may reach across relationships: Foodio's kitchen list filters order items by their order's delivery date.
- **`capacity` needs its parameter.** `presentation: BeakSummaryPresentation.capacity` without a `capacity:` throws a `BeakConfigurationException` that names the summary by its title and asks for the used and total measures. It happens when the block renders, and nothing asserts it earlier, so a widget test is where you find it.
- **English UI text.** The truncation line ("Only the first groups are shown...") and the `presentation` suffix of the toggle's screen-reader name are English whatever the panel locale. The toggle's own "Chart view" and "Table view" labels follow the panel's language.
- **The palette.** Without a color, series and segments cycle through the theme's primary, warning, info, success and error colors. Charts built by `BeakChartBlock` use the theme's chart palette instead, so a summary and a chart on one page can disagree. Set `color` on the values, or in `groupStyle`, when they must match ([Colors and tokens](../theming/colors-and-tokens.md)).

## Verify it

The presentation tests build every kind of summary against a source that answers `summary`:

```console
$ cd packages/beak_frontend
$ flutter test --no-pub test/src/panel/beak_summary_presentation_test.dart
00:00 +0: conditional donut and accessible table share one authoritative result
00:01 +1: group labels come from the summarised field, declared once
00:01 +2: capacity compares the used and total measures by object
00:01 +3: a capacity presentation without a capacity names the mistake
00:01 +4: All tests passed!
```

The server side is covered by `packages/beak_backend/test/src/data/worm/summary_test.dart` and `summary_sqlite_test.dart`. To see the real numbers, run the Aviary API and use the `curl` requests above.

## Reference

The first three constructors are the measures. A measure is created once and passed by object:

```dart title="packages/beak_core/lib/src/query/beak_summary_spec.dart"
--8<-- "packages/beak_core/lib/src/query/beak_summary_spec.dart:BeakSummaryMeasure"
```

The spec comes from the model, never from a table string:

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
--8<-- "packages/beak_core/lib/src/model/beak_model.dart:BeakModelSummary"
```

The block and its parts:

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryBlock"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryValue"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryCapacity"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryGroupStyle"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryLegend"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryScope"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_summary_block.dart:BeakSummaryPresentation"
```

The wire types are `BeakSummarySpec`, `BeakSummaryRow` (`group`, `values`, `valueOf(measure)`, `decimalOf(measure)`), `BeakSummaryResult` (`rows`, `truncated`) and the capability interface `BeakSummaryDataSource`, all in `beak_core`. The endpoint is listed on [REST API](../reference/rest-api.md).

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md) where `header` and `collapsedHeader` live.
- [Dashboards](../panel/dashboards.md) summaries next to metrics and tables on an overview page.
- [Charts](charts.md) the block for data that does not fit the summary contract.
- [Formatting and localization](../theming/formatting-and-localization.md) how the numbers and dates in a summary are formatted.
