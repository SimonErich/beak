---
title: Dashboards
description: Two ways to build the panel's landing page: config-only stats and charts, or a full custom block tree mounted at the home route.
---

# Dashboards

After this page you can give a Beak panel a landing page two ways: the quick one,
where you list a few `BeakStat`s and `BeakChart`s on the config and Beak draws the
cards for you, and the open one, where you hand the home route a `BeakScreen` whose
body is any tree of blocks you like.

Both dashboards fetch live numbers through the same data source. Nothing is
hardcoded, and neither approach makes you write a widget.

## The two approaches

Beak mounts a dashboard at `/` for you. What lives there depends on your config:

| You provide | What renders at `/` | Best for |
| --- | --- | --- |
| `dashboardStats` / `dashboardCharts` | Beak's generated `BeakDashboard`: a wrapping row of stat cards, then the charts | A handful of KPIs and charts with no layout fuss |
| A `BeakScreen(path: '/')` on `pages` | Your block tree, verbatim | A designed landing page: grids, maps, tables, module blocks |

The rule is short: **if any custom page claims `/`, it replaces the built-in
dashboard entirely.** Otherwise Beak falls back to the stats-and-charts version.
You never wire both.

## Approach one: config-only stats and charts

This is the teaching store (`examples/store`, port 8080). You declare the metrics
and the charts as data on `BeakPanelConfig`, and Beak renders `BeakStatCard`s and
`BeakChartCard`s that each fetch their own aggregate or query.

```dart
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [ /* ... */ ],
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
);
```

!!! note "What just happened"
    - Each `BeakStat` is a labelled `BeakAggregateSpec`. `count` needs only a table;
      `sum` and `avg` take a column constant (`ProductColumns.price`), never a key
      string, so the total is type-checked.
    - `BeakStat.count(...)` is a `const` constructor, so those two tiles are `const`.
      `sum` reads `column.key`, so the "Catalog value" tile drops the `const`. That
      is a compiler detail, not something you configure.
    - `prefix: '€'` sits in front of the formatted number. There is a matching
      `suffix` for units like ` items`.

### A stat wraps an aggregate

A `BeakStat` carries a `BeakAggregateSpec`, the same typed, JSON-serializable
aggregate the backend understands. The card runs it through the repository and
shows the number. Integer results render without decimals, fractional ones with
two.

```dart title="packages/beak_core/lib/src/query/beak_aggregate_spec.dart"
/// Counts the rows of [table] matching [filter].
const BeakAggregateSpec.count({
  required this.table,
  this.filter,
  this.withTrashed = false,
});

/// Sums [column] over the rows of [table] matching [filter].
BeakAggregateSpec.sum({
  required this.table,
  required BeakColumn column,
  this.filter,
  this.withTrashed = false,
});

/// Averages [column] over the rows of [table] matching [filter].
BeakAggregateSpec.avg({
  required this.table,
  required BeakColumn column,
  this.filter,
  this.withTrashed = false,
});
```

Every spec can carry a `filter`, so a stat can count "orders placed this month" or
sum "revenue from paid invoices". The filter is the same `BeakFilter` your tables
and query specs use.

### A chart is a query plus a typed mapper

A `BeakChart` is three things: a `BeakQuerySpec` that fetches records, a `map` that
turns those records into typed points, and a `type` that picks the chart family.

```dart
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

The mapper reads fields through the shared column constants, so the chart never
touches a string field reference or `dynamic`. Its signature is the
`BeakChartMapper` typedef:

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
typedef BeakChartMapper =
    List<BeakChartPoint> Function(List<BeakRecord> records);
```

`BeakChartType` picks how those points draw. Every family maps from the same
`List<BeakChartPoint>`:

| `BeakChartType` | Shape |
| --- | --- |
| `line` | A line over the mapped points |
| `bar` | One vertical bar per point |
| `pie` | One segment per point |
| `donut` | A ring, one segment per point |
| `area` | A filled line over the points |
| `radar` | One axis per point, a single series |
| `funnel` | One stage per point |

Richer shapes (bubble, candlestick, heatmap) belong to the chart blocks. See
[Chart basics](../charts/chart-basics.md).

## Approach two: a custom block-tree dashboard

When you want a designed landing page (a KPI grid, a chart beside a donut, a world
map, a stack of tables), return a `BeakScreen` mounted at `/` and put it on
`pages`. This is the showcase (`superdashboard`, port 8180).

```dart title="examples/superdashboard/lib/panel/dashboard.dart"
BeakScreen buildDashboardScreen() => BeakScreen(
  path: '/',
  title: 'Dashboard',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [_kpis(), _chartsAndDonut(), _mapAndAudience(), _tables()],
  ),
);
```

Because `path` is `/`, this screen wins the home route and the generated
stats-and-charts dashboard steps aside. The body is a plain block column; each
child is a grid of data-bound blocks.

```dart title="examples/superdashboard/lib/panel/dashboard.dart"
BeakBlock _kpis() => BeakGridBlock(
  columns: 4,
  children: [
    // sum() is not a const constructor (it reads column.key), so this tile
    // is built at runtime; the count tiles stay const.
    BeakKpiBlock(
      title: 'Total earnings',
      value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
      format: BeakKpiFormat.currency,
    ),
    const BeakKpiBlock(
      title: 'Total orders',
      value: BeakAggregateSpec.count(table: 'orders'),
    ),
    const BeakKpiBlock(
      title: 'Customers',
      value: BeakAggregateSpec.count(table: 'users'),
    ),
    const BeakKpiBlock(
      title: 'Products',
      value: BeakAggregateSpec.count(table: 'products'),
    ),
  ],
);
```

A `BeakKpiBlock` is the block-world cousin of `BeakStat`: a headline aggregate,
plus an optional `previous` aggregate that drives an up/down delta badge, an
optional `target`, and a `format`.

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

`BeakKpiFormat` is `number`, `currency`, or `percent`. Both the headline and the
delta run through the data source, so the numbers are always live.

The rest of the tree is more of the same, composed from data blocks: a
`BeakChartBlock` next to a donut, a `BeakMapBlock` of live users by country, and
`BeakTableBlock`s for the latest orders, top customers, and transactions.

```dart title="examples/superdashboard/lib/panel/dashboard.dart"
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
    // ... top customers, latest transactions
  ],
);
```

!!! question "What this skipped"
    A `BeakScreen` at `/` is one custom screen; the same type builds every other
    page in the showcase (chat, invoice, pricing, and so on). The screen anatomy
    (`path`, `title`, `icon`, `section`, `showInNav`, `framed`) lives on
    [Custom screens](custom-screens.md). The data blocks used above are cataloged
    in [Data blocks](../blocks/data-blocks.md).

## Which one to reach for

Start with `dashboardStats` and `dashboardCharts`. They are two lists on the config
and you get a working dashboard with zero layout code. Graduate to a
`BeakScreen(path: '/')` the day you want control over the grid: where the KPIs
sit, what shares a row, which tables land at the bottom.

## Reference

`BeakStat` (from `packages/beak_frontend/lib/src/dashboard/beak_stat.dart`):

```dart title="packages/beak_frontend/lib/src/dashboard/beak_stat.dart"
const BeakStat({
  required this.label,
  required this.aggregate,
  this.icon,
  this.prefix = '',
  this.suffix = '',
});
```

`BeakChart` and `BeakChartPoint` (from
`packages/beak_frontend/lib/src/dashboard/beak_chart.dart`):

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
const BeakChart({
  required this.title,
  required this.type,
  required this.query,
  required this.map,
  this.heightInPixels = 260,
});

const BeakChartPoint({required this.label, required this.value, this.x});
```

Both `dashboardStats` and `dashboardCharts` default to empty lists on
`BeakPanelConfig`, so a dashboard with no metrics is valid: you see an empty
landing page until you add the first `BeakStat`.

## Continue reading

- [Custom screens](custom-screens.md) the `BeakScreen` anatomy behind the block-tree dashboard.
- [Data blocks](../blocks/data-blocks.md) the KPI, chart, table, and map blocks a custom dashboard is built from.
- [Chart basics](../charts/chart-basics.md) chart types, points, and the mapper pattern in full.
- [7. A custom dashboard](../tutorial/07-a-custom-dashboard.md) the same story, built step by step in the tutorial.
