---
title: Dashboards
description: Build an overview page from live metric, table and summary blocks, make it the landing page, and keep its numbers current.
type: guide
audience: [beginner]
status: stable
---

# Dashboards

A dashboard in Beak is a `BeakScreen` at `/` made of blocks. There is no dashboard class, no chart wiring and no fetch code: each block asks the server for its own number and asks again when the panel writes to the table behind it.

## At a glance

| Question | Answer |
| --- | --- |
| Where is it declared | Authored panel: any file, listed in `pages:` (the shop uses `lib/overview.dart`). Generated panel: a top-level `BeakScreen`, or a function returning one, under `lib/screens/` |
| How does the panel open on it | Give the screen `path: '/'`, or point `home:` at it |
| What is it made of | `BeakMetricBlock` for one number, `BeakSummaryBlock` for grouped figures, `BeakTableBlock` for rows, `BeakWidgetBlock` for your own widget, inside `BeakColumnBlock`, `BeakGridBlock`, `BeakCardBlock` and `BeakSectionBlock` |
| Who fetches | The block, through the panel's data source. You write no ViewModel or repository |
| How current is it | Fresh after any write made through this panel, and on a timer if you set a `refreshPolicy` |

Everything on this page is a screen, so [Custom screens](custom-screens.md) covers the parameters (`path`, `title`, `framed`, `navigationGroup`) and how the generated panel discovers the file.

## Make it the landing page

The panel needs one answer to "where does `/` go". It takes the first that applies:

| You declare | `/` does this |
| --- | --- |
| A `BeakScreen` with `path: '/'` | Shows that screen. It is the landing page |
| `home:` set to a resource or a screen | Redirects there, while the destination is visible |
| Nothing | Redirects to the first visible destination of the `BeakNavigation`, then of the resources, then of the pages that show in the sidebar |

Sign-in returns to `/`, and so does the "back to dashboard" button of the error pages. `home:` takes a typed destination, `home: overviewScreen` or `home: OrderResource()`, never a route string. It must be one of the panel's own resources or pages, and it cannot point anywhere else while a screen already claims `/`. Both mistakes throw a `BeakConfigurationException` when the panel starts.

Foodio's overview lives at `/overview` and is the first item of its navigation, so `/` redirects there. The shop and the showcase put their overview on `/`.

## The shop's overview

The shop's page is four metrics, a receivables card, two small tables and a section of workflow notes.

```dart title="examples/clean_beak_config/lib/overview.dart"
--8<-- "examples/clean_beak_config/lib/overview.dart:shopOverview"
```

Three things carry the page.

A `BeakMetricBlock` takes a label and an aggregate: `const ProductModel().count()`, or a `count(filter: ...)` with a typed filter. It shows the value on a card, with a loading state and a retry when the request fails. Money stored as integer cents sets `minorUnits: true` and a `format: BeakValueFormat.currency`, and `previous:` and `target:` add the change against a period and a progress track.

A `BeakTableBlock` is a short table of the model. `initialSpec` sets the sort and the page size (five rows here), `baseFilter` is a permanent filter the reader cannot remove, and `enableDelete: false` drops the row delete button that a table block otherwise has.

`BeakGridBlock(minColumnWidthInPixels: 220)` lays the cards out in as many columns as fit and stacks them on a phone.

The card that counts "Orders to fulfill" and the queue on the operations page share one definition, `fulfillmentQueueFilter()`. The number on the card and the rows behind it cannot disagree, because both come from the same object.

## Grouped figures

A metric is one number. For a number split by a field, or several numbers side by side, use a `BeakSummaryBlock`. Foodio's status donut counts today's orders by state:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioStatusDonut"
```

`query` is a `model.summary(groupBy:, filter:, measures:)` and `values` says how each measure is labelled and formatted. `presentation` is `metrics`, `strip`, `bar`, `donut`, `table` or `capacity`. The summary is computed on the server over the whole population, not over a page of rows.

`scope` chooses which surrounding query the block inherits. Inside a composed list's header, `active` follows the list's filters and `base` only its permanent scope. On a dashboard there is no list to inherit from, so all three values behave alike, and foodio sets `standalone` on the blocks of its overview to say so. The blocks are in [Data blocks](../blocks/data-blocks.md) and [Population summaries](../blocks/summaries.md), and [A dashboard KPI](../recipes/a-dashboard-kpi.md) builds one from scratch.

A summary needs a data source that answers grouped summaries. The HTTP source does. A source that does not shows `This source does not support grouped summaries.` in the card instead of a chart.

## A card of your own

When no block fits, a `BeakWidgetBlock` embeds a widget, and the widget has the same tools the blocks use. The shop keeps money as exact decimals (`BeakDecimal`), and its receivables card reads the total with the field's own exact `sum`:

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesData"
```

`useBeakDataRevision(source, table: ...)` returns a counter that goes up whenever a write touches that table, and putting it in the memo key refetches the sum. `InvoiceModel.total.sum(...)` returns a `BeakDecimal` and throws instead of rounding. The rest of the card is the states every data widget owes its reader:

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesStates"
```

Loading shows a progress bar, a failure shows the message and a retry button, and a zero says so in words. A false zero is the one state to avoid: a failed request must not read as "nothing to collect". The shop has a test for exactly that.

## Keep it current

Blocks refetch on their own after writes made through this panel: a save in a form, a delete, a bulk edit. They cannot know about a colleague's write in another browser. For that, set a `refreshPolicy` on the panel:

```dart title="examples/foodio-adminpanel/lib/main.dart"
refreshPolicy: const BeakRefreshPolicy(
  interval: Duration(seconds: 30),
  onResume: true,
),
```

| Field | Default | Meaning |
| --- | --- | --- |
| `interval` | `null` | Poll cadence. `null` means no polling: only local writes and a return to the foreground refresh |
| `onResume` | `true` | Refreshes when the app returns from the background |

A tick marks every registered table as changed, so every block on screen refetches. A window in the background does not poll. Foodio polls every 30 seconds; a page with a dozen blocks makes a dozen requests per tick, which is the number to weigh before you shorten the interval. A remote refresh updates clean records and leaves unsaved form edits alone.

## Rules and limits

- A screen is built once, when the app starts. A date you compute inside it (`DateTime.now()`) stays the date of that start. Foodio pins `foodioToday` for that reason, and it is a demo choice, not a pattern.
- Table, metric and summary blocks refetch after a write to their table. Chart, kanban and calendar blocks do not yet, so a dashboard that puts one of them on screen shows stale figures until the page reloads.
- Each metric costs one request (two with `previous`), each summary one, each table block one page. Twenty blocks are twenty requests on every refresh.
- A dashboard has no permission of its own. Every block reads through the data source, and the server's row and field rules decide what appears. An account that may not read a model sees the error state in that block.
- `lib/dashboard.dart` with a `beakDashboard()` function is no longer read. `beak prepare` stops and says what to do (see below). Declare a `BeakScreen` with `path: '/'` under `lib/screens/` and delete the file.

## Verify it

The shop's overview is pumped against an in-memory source and must render its metrics and both tables without an exception:

```console
$ cd examples/clean_beak_config
$ flutter test test/shop_widget_test.dart --plain-name "shop overview"
00:00 +0: shop overview loads its operational metrics and tables
00:01 +1: All tests passed!
```

The refresh policy has package tests for the timer and the resume path:

```console
$ cd packages/beak_frontend
$ flutter test test/src/data/beak_refresh_policy_test.dart --reporter expanded
00:00 +0: one subscribed timer pauses in background and refreshes on resume
00:00 +1: remote refresh updates a clean record and preserves dirty form edits
00:00 +2: All tests passed!
```

In a scratch project, the removed override is refused, and a screen under `lib/screens/` is picked up (`beak create dash --no-pub --no-example`, then `beak prepare`):

```console
$ beak prepare
...
  lib/dashboard.dart: Beak no longer reads the beakDashboard() override. Declare the screen as a BeakScreen with path: '/' under lib/screens/ instead, and the panel opens on it. Then delete this file.
$ rm lib/dashboard.dart
$ beak prepare
  0 models · 0 resource classes · 1 screen · 0 overrides
  generated  6 of 7 files
```

## Reference

| Symbol | Notes |
| --- | --- |
| `BeakScreen(path: '/', ...)` | Claims the landing route. See [Custom screens](custom-screens.md) |
| `BeakPanelConfig.home`, `BeakPanel(home:)` | `BeakDestination?`, a `BeakResource` or a `BeakScreen` |
| `BeakMetricBlock` | `label`, `aggregate`, `icon`, `format`, `minorUnits`, `scale`, `unit`, `previous`, `target`, `span` |
| `BeakSummaryBlock` | `title`, `query`, `values`, `presentation`, `scope`, `heightInPixels`, plus chart options |
| `BeakSummaryScope` | `active`, `base`, `standalone` |
| `BeakTableBlock` | `model`, `title`, `columns`, `fields`, `enableDelete`, `initialSpec`, `baseFilter`, `actions`, `onRowTap`, `heightInPixels` |
| `BeakRefreshPolicy` | `const BeakRefreshPolicy({this.interval, this.onResume = true})` |
| `useBeakDataRevision` | `int useBeakDataRevision(BeakDataSource? source, {String? table})`, a hook for widgets |
| `BeakExactDecimalAggregates.sum` | `Future<BeakDecimal> sum(BeakDataSource source, {BeakFilter? filter, bool withTrashed = false})` on a `BeakScalarField<BeakDecimal>` |

```dart title="packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_metric_block.dart:BeakMetricBlock"
```

## Continue reading

- [Data blocks](../blocks/data-blocks.md) metric, table and timeline blocks in full.
- [Population summaries](../blocks/summaries.md) the grouped figures a summary block draws.
- [A dashboard KPI](../recipes/a-dashboard-kpi.md) one metric, start to finish.
- [Composed lists and query state](composed-lists.md) putting a summary header above a list.
