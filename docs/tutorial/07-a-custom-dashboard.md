---
title: 7. A custom dashboard
description: Give the roastery a landing page, first with config-only stats and charts, then a custom block screen at the root route.
---

# 7. A custom dashboard

By the end of this chapter your store opens on a dashboard. You will start with
the config-only version Beak gives every panel (metric cards and a chart, declared
as data on `BeakPanelConfig`), then replace it with a custom screen you compose
from blocks: a row of KPI tiles and a bar chart, all reading live from the store's
own tables.

Your customers see a table of products first. You, the shopkeeper, want the shape
of the business at a glance. That is what a dashboard is for.

## The config-only dashboard

Beak mounts a dashboard at `/` for free. You do not write a widget; you list the
numbers you want. The panel builder you have been growing since chapter 3 already
carries two lists: `dashboardStats` (the metric cards) and `dashboardCharts` (the
graphs).

Here is the real dashboard the reference store ships:

```dart
dashboardStats: [
  const BeakStat(
    label: 'Products',
    aggregate: BeakAggregateSpec.count(table: 'products'),
    icon: OiIcons.package,
  ),
  const BeakStat(
    label: 'Customers',
    aggregate: BeakAggregateSpec.count(table: 'users'),
    icon: OiIcons.users,
  ),
  BeakStat(
    label: 'Catalog value',
    aggregate: BeakAggregateSpec.sum(
      table: 'products',
      column: ProductColumns.price,
    ),
    icon: OiIcons.euro,
    prefix: '€',
  ),
],
dashboardCharts: [
  const BeakChart(
    title: 'Stock per product',
    type: BeakChartType.bar,
    query: BeakQuerySpec(table: 'products'),
    map: stockPerProduct,
  ),
],
```

Each `BeakStat` is a labelled aggregate. `BeakAggregateSpec.count(table: 'products')`
counts rows; `BeakAggregateSpec.sum` totals a column, addressed through the typed
constant `ProductColumns.price` (never the string `'price'`). The `count`
constructor is `const`; `sum` reads `column.key`, so its tile is built at runtime.
The card shows the formatted result with your `prefix`/`suffix` around it.

A `BeakChart` pairs a query with a mapping. The `query` fetches a page of records,
`map` turns them into typed points, and `type` picks the chart family. The mapper
is a plain, typed function, also reading through column constants:

```dart
/// Maps a page of product records onto stock-per-product chart points.
List<BeakChartPoint> stockPerProduct(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: record[ProductColumns.name.key]?.raw?.toString() ?? '',
      value: switch (record[ProductColumns.stock.key]?.raw) {
        final num stock => stock.toDouble(),
        _ => 0,
      },
    ),
];
```

That is a whole dashboard, and not one line of it fetches or plumbs data by hand.
The stat cards and chart card query through the same repository your tables use.

!!! tip "Every number is live"
    The aggregates and the chart query run against the backend on each load. There
    is nothing hardcoded to drift out of date; change the data and the tiles follow.

## A custom screen at the root route

The config-only dashboard is a fixed shape: a strip of cards, then charts. When you
want your own arrangement (KPI tiles beside a chart, tabs, tables, whatever the
roastery needs) you reach for a `BeakScreen`: a route, a nav entry, and a
declarative block tree for its body.

A `BeakScreen` whose `path` is `'/'` replaces the built-in stats/charts dashboard
wholesale. Add this to your store, next to `buildReferencePanelConfig` in
`examples/store/lib/main.dart`:

```dart
/// A custom home screen: KPI tiles and a chart over the store's own tables.
/// A screen mounted at '/' takes over the root route from the built-in
/// stats/charts dashboard.
BeakScreen buildStoreDashboard() => BeakScreen(
  path: '/',
  title: 'Dashboard',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [
      BeakGridBlock(
        columns: 4,
        children: [
          const BeakKpiBlock(
            title: 'Products',
            value: BeakAggregateSpec.count(table: 'products'),
          ),
          const BeakKpiBlock(
            title: 'Customers',
            value: BeakAggregateSpec.count(table: 'users'),
          ),
          const BeakKpiBlock(
            title: 'Orders',
            value: BeakAggregateSpec.count(table: 'orders'),
          ),
          BeakKpiBlock(
            title: 'Catalog value',
            value: BeakAggregateSpec.sum(
              table: 'products',
              column: ProductColumns.price,
            ),
            format: BeakKpiFormat.currency,
            currencySymbol: '€',
          ),
        ],
      ),
      const BeakChartBlock(
        title: 'Stock per product',
        type: BeakChartType.bar,
        query: BeakQuerySpec(table: 'products'),
        map: stockPerProduct,
      ),
    ],
  ),
);
```

Read the block tree top to bottom, because that is exactly how it renders. A
`BeakColumnBlock` stacks its children with a gap. The first child is a
`BeakGridBlock` of four `BeakKpiBlock` tiles across four columns; the second is a
`BeakChartBlock` reusing the very same `stockPerProduct` mapper the config chart
used. `BeakKpiBlock` takes the same `BeakAggregateSpec` as `BeakStat`, so the
three `count` tiles stay `const` while the `sum` tile (catalog value) is built at
runtime, the same as before.

Now register the screen. Custom, non-resource screens go on `pages`. Add this key
to the `BeakPanelConfig` you return from `buildReferencePanelConfig`:

```dart
pages: [buildStoreDashboard()],
```

That is all the wiring. The screen becomes the root route, gets a sidebar entry,
and joins the Ctrl/Cmd-K command bar automatically.

!!! question "What this skipped"
    KPI tiles can also carry a `previous` aggregate to draw an up/down delta, and a
    `target` to draw a progress track. See
    [Data blocks](../blocks/data-blocks.md) for the full set, and
    [Dashboards](../panel/dashboards.md) for the config-only path in depth.

## Run it

Your backend from chapter 3 should still be serving on port 8080. Launch the panel:

```bash
cd examples/store
flutter run -d chrome
```

Chrome opens on the root route and, instead of the stats strip, you now see your
custom dashboard: four KPI tiles (Products, Customers, Orders, and a `€` Catalog
value) sitting above a "Stock per product" bar chart, one bar per seeded product.
The sidebar shows a "Dashboard" entry at the top, and Ctrl-K (or Cmd-K) can jump to
it by name.

!!! note "What just happened"
    - `dashboardStats` and `dashboardCharts` are the config-only dashboard: typed
      aggregates and a mapped query, no widget code.
    - A `BeakScreen` at `'/'` replaces that dashboard with a block tree you own.
    - Blocks are pure `const` configuration. `BeakColumnBlock`, `BeakGridBlock`,
      `BeakKpiBlock`, and `BeakChartBlock` compose into a page the same way columns
      compose into a table.
    - Every aggregate and query reads live through the data source, addressed with
      column constants rather than strings.

## Continue reading

- [8. Forms, wizards, and dual-mode detail](08-forms-wizards-and-dual-mode-detail.md) build bespoke create and edit surfaces next.
- [Dashboards](../panel/dashboards.md) the config-only stats and charts in full.
- [Data blocks](../blocks/data-blocks.md) KPI, metric, table, calendar, and kanban blocks.
- [The block system](../concepts/the-block-system.md) how one sealed union drives every non-CRUD surface.
