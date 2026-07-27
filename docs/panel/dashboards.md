---
title: Dashboards
description: Two ways to build the panel's landing page: a lib/dashboard.dart block tree, or config-only stats and charts from lib/panel.dart.
---

# Dashboards

After this page you can give a Beak panel a landing page two ways: the open one,
where `lib/dashboard.dart` hands the home route a `BeakScreen` whose body is any
tree of blocks, and the quick one, where a few `BeakStat`s and `BeakChart`s on
the config make Beak draw the cards for you.

Both dashboards fetch live numbers through the same data source. Nothing is
hardcoded, and neither approach makes you write a widget.

## The two approaches

Beak mounts something at `/` whatever you do. What lives there depends on which
file exists:

| You provide | What renders at `/` | Best for |
| --- | --- | --- |
| `lib/dashboard.dart` declaring `beakDashboard()` | Your block tree, verbatim | A designed landing page: grids, charts, maps, tables |
| `dashboardStats` / `dashboardCharts` on the config | Beak's generated `BeakDashboard`: a wrapping row of stat cards, then the charts | A handful of KPIs and charts with no layout fuss |
| Neither | An empty dashboard page | A panel that is all resources |

The rule is short: **a page that claims `/` replaces the built-in dashboard
entirely.** `beak prepare` puts `beakDashboard()` first on `pages`, and the
router only mounts the stats-and-charts dashboard when no page claims the home
route. You never wire both.

## Approach one: a lib/dashboard.dart block tree

Declare `BeakScreen beakDashboard()` in `lib/dashboard.dart` and Beak wires it
into `pages` for you. Nothing else registers it: the file name and the function
name are the whole contract.

```dart title="examples/store/lib/dashboard.dart"
/// The screen mounted at `/`, replacing the generated dashboard.
///
/// Four numbers, one chart and the two lists a shopkeeper opens the panel to
/// read. Every figure is a [BeakAggregateSpec] the API computes — nothing is
/// counted in the browser, and nothing is hardcoded.
BeakScreen beakDashboard() => const BeakScreen(
  path: '/',
  title: 'Today',
  icon: BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(gapInPixels: 20, children: [_kpis, _revenue, _lists]),
);
```

Because `path` is `/`, this screen wins the home route. The body is a plain
block column, and each child is a grid of data-bound blocks.

```dart title="examples/store/lib/dashboard.dart"
const BeakBlock _kpis = BeakGridBlock(
  columns: 4,
  children: [
    BeakKpiBlock(
      title: 'Revenue',
      value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
      format: BeakKpiFormat.currency,
      currencySymbol: '€',
    ),
    BeakKpiBlock(
      title: 'Orders',
      value: BeakAggregateSpec.count(table: 'orders'),
    ),
    BeakKpiBlock(
      title: 'Awaiting payment',
      value: BeakAggregateSpec.count(
        table: 'orders',
        filter: BeakFieldFilter(
          column: OrderColumns.status,
          operator: BeakOperator.eq,
          value: BeakStringValue('pending'),
        ),
      ),
    ),
    BeakKpiBlock(
      title: 'Out of stock',
      value: BeakAggregateSpec.count(
        table: 'products',
        filter: BeakFieldFilter(
          column: ProductColumns.stock,
          operator: BeakOperator.eq,
          value: BeakIntValue(0),
        ),
      ),
    ),
  ],
);
```

!!! note "What just happened"
    - Every tile is a `BeakAggregateSpec` the API computes. The browser receives
      a number, not a table to count.
    - `count`, `sum` and `avg` are all `const` constructors, so the whole grid is
      one `const` expression.
    - `OrderColumns.total` and `ProductColumns.stock` are generated from the
      `total` and `stock` fields of the `Order` and `Product` schema classes.
      Rename a field and this file stops compiling, which is the point.
    - A filter narrows an aggregate: "awaiting payment" is the same `count` with
      a `BeakFieldFilter` on it.

A `BeakKpiBlock` is a headline aggregate, plus an optional `previous` aggregate
that drives an up/down delta badge, an optional `target`, and a `format`.

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

### A chart is a query plus a typed mapper

A chart block is three things: a `BeakQuerySpec` that fetches records, a `map`
that turns those records into typed points, and a `type` that picks the chart
family.

```dart title="examples/store/lib/dashboard.dart"
const BeakBlock _revenue = BeakChartBlock(
  title: 'Order totals',
  type: BeakChartType.bar,
  query: BeakQuerySpec(
    table: 'orders',
    sorts: [BeakSort('placed_at')],
    pagination: BeakPagination(perPage: 30),
  ),
  map: orderTotalPoints,
);

/// One bar per order: its reference and what it was worth.
///
/// A mapper reads through the generated column constants, so renaming a
/// column in the schema class is a compile error here rather than an empty
/// chart in production.
List<BeakChartPoint> orderTotalPoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: OrderColumns.reference.readFrom(record) ?? '—',
      value: OrderColumns.total.readFrom(record) ?? 0,
    ),
];
```

`readFrom` is the typed read: `OrderColumns.total.readFrom(record)` is a
`double?` at compile time, because `total` is a `double` on the schema class. No
key strings, no `dynamic`, no casts. The mapper's signature is the
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

### Tables and lists on a dashboard

The rest of a dashboard is more of the same. The store closes with two live
tables, each one a `BeakTableBlock` over a model with an explicit column list:

```dart title="examples/store/lib/dashboard.dart"
const BeakBlock _lists = BeakGridBlock(
  columns: 12,
  children: [
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
    // … featured products
  ],
);
```

The superdashboard's `lib/dashboard.dart` is the same idea at showcase scale:
four KPI tiles, an area chart beside a donut, a world map of live users beside a
bar chart, and three tables.

!!! question "What this skipped"
    A `BeakScreen` at `/` is one custom screen; the same type builds every other
    page you add under `lib/screens/`. The screen anatomy (`path`, `title`,
    `icon`, `section`, `showInNav`, `framed`) lives on
    [Custom screens](custom-screens.md). The data blocks used above are cataloged
    in [Data blocks](../blocks/data-blocks.md).

## Approach two: config-only stats and charts

If you want numbers on the home page and no layout decisions, skip
`lib/dashboard.dart` and set `dashboardStats` and `dashboardCharts` instead.
Those live on `BeakPanelConfig`, so the place to set them is `lib/panel.dart`,
the hook that sees the finished config:

```dart
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults.copyWith(
  dashboardStats: const [
    BeakStat(
      label: 'Products',
      aggregate: BeakAggregateSpec.count(table: 'products'),
      icon: OiIcons.package,
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
  dashboardCharts: const [
    BeakChart(
      title: 'Stock per product',
      type: BeakChartType.bar,
      query: BeakQuerySpec(table: 'products'),
      map: stockPerProduct,
    ),
  ],
);
```

Beak renders a `BeakStatCard` per stat and a `BeakChartCard` per chart, each
fetching its own aggregate or query. `prefix: '€'` sits in front of the
formatted number; there is a matching `suffix` for units like ` items`.

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
  }) : function = BeakAggregateFunction.count,
       _column = null,
       _columnKey = null;

  /// Sums [column] over the rows of [table] matching [filter].
  const BeakAggregateSpec.sum({
    required this.table,
    required BeakColumn column,
    this.filter,
    this.withTrashed = false,
  }) : function = BeakAggregateFunction.sum,
       _column = column,
       _columnKey = null;
```

`BeakAggregateSpec.avg` has the same signature as `sum`. `count` needs only a
table; `sum` and `avg` take a generated column constant,
never a key string, so the total is type-checked. Every spec can carry a
`filter`, so a stat can count "orders placed this month" or sum "revenue from
paid invoices". The filter is the same `BeakFilter` your tables and query specs
use.

## Which one to reach for

Reach for `lib/dashboard.dart`. It is one file, one function, and you control
the grid: where the KPIs sit, what shares a row, which tables land at the
bottom. The store and the superdashboard both do it that way.

`dashboardStats` and `dashboardCharts` are the shortcut when the landing page is
five numbers and you would rather not decide anything about them. They also
stay useful as a starting point: delete them the day you add
`lib/dashboard.dart`, because the file wins the route either way.

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
```

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
  const BeakChartPoint({required this.label, required this.value, this.x});
```

Both `dashboardStats` and `dashboardCharts` default to empty lists on
`BeakPanelConfig`, so a panel with neither and no `lib/dashboard.dart` is valid:
you see an empty landing page until you add the first block or the first stat.

## Continue reading

- [Custom screens](custom-screens.md) the `BeakScreen` anatomy behind the block-tree dashboard.
- [Data blocks](../blocks/data-blocks.md) the KPI, chart, table, and map blocks a custom dashboard is built from.
- [Chart basics](../charts/chart-basics.md) chart types, points, and the mapper pattern in full.
- [The panel](index.md) where `lib/dashboard.dart` and `lib/panel.dart` sit among the other project files.
