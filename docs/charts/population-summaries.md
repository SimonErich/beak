---
title: Population summaries
description: Declarative, authorized aggregates independent of the current table page.
---

# Population summaries

Use `BeakSummaryPresentation.strip` for a compact row of labelled values, such as
today's order count, revenue and attention count. It uses the same typed measures,
formatting, loading/error handling and refresh invalidation as chart presentations.
The strip omits a visible heading while retaining its accessible title, and wraps
into fewer columns as space narrows. It is useful as a composed list's
`collapsedHeader` when the full charts are hidden.

Use `BeakSummaryBlock` for a metric, grouped bar chart, donut, capacity display, or compact summary table. Beak owns loading, errors, retries, mutation refresh and the chart/table switch. The server aggregates the complete authorized population; loading 15 rows in a table never limits its dashboard to those 15 records.

```dart
BeakSummaryBlock(
  title: 'Orders by delivery date',
  query: BeakSummarySpec(
    table: const OrderModel().table,
    groupBy: OrderModel.deliveryDate.column,
    measures: const [BeakSummaryMeasure.count('orders')],
  ),
  groupField: OrderModel.deliveryDate,
  values: const [
    BeakSummaryValue(
      measure: BeakSummaryMeasure.count('orders'),
      label: 'Orders',
    ),
  ],
  presentation: BeakSummaryPresentation.bar,
  showTableToggle: true,
)
```

Inside a composed list, `scope: active` inherits its permanent scope, selected preset, user filters and search. Pagination and sorting do not affect the summary. `base` inherits only the list's permanent query. `standalone` uses the block's own query, including when it targets another model such as delivery slots.

A summary supports one scalar grouping dimension, one to eight uniquely keyed measures, and a group limit of 1–500. The response marks truncated groups explicitly. Calendar dates are stored dates; the API does not silently bucket instants into a guessed timezone. Unsupported data sources report a configuration error through `BeakSummaryDataSource`.

## Conditional measures

A measure can declare an additional typed filter. Its population is the intersection of that filter, the summary query, and the authorized row scope. This is useful for mutually exclusive operational categories without adding redundant status columns to the database.

```dart
BeakSummaryMeasure.count(
  'confirmed',
  filter: BeakAndFilter([
    OrderModel.status.eq(OrderStatus.confirmed),
    OrderModel.needsAttention.eq(false),
  ]),
)
```

An ungrouped donut renders one segment per configured measure. A grouped donut renders one segment per group using its first measure. A center label displays their total; overlapping conditional populations therefore should not be described as a count of distinct records.

## Presentation

Summary charts inherit Obers chart tokens from `components.chart`. The bar axes
use `axis.labelStyle` and `axis.labelColor`, and the donut's value legend uses
`legend.labelStyle`, `labelColor`, `iconSize`, `spacing` and `padding`. Keep these
shared choices in the panel theme; resources only configure content and layout.

`BeakSummaryValue` carries the label, format, optional color, and integer currency storage units (`minorUnits`, `scale`). `groupStyle` supplies a label, section, color and `hatched` forecast treatment without changing data. `groupOrder` controls presentation order. Bars accept `maximum`, `divisions` and `showValues`; the optional footer reads the loaded result. `legend` accepts `BeakSummaryLegend` entries with a label, color and optional hatch pattern. Capacity tracks also accept `warningColor` independently from their readable warning text.

`BeakSummaryPresentation.capacity` pairs two measure keys:

```dart
capacity: BeakSummaryCapacity(
  used: 'booked',
  total: 'capacity',
  warningThreshold: .95,
  warning: (row) => '${row.values['capacity']! - row.values['booked']!} remaining',
),
```

The resulting Obers capacity indicator provides an accessible ratio, a clamped visual track, a patterned remainder and an optional warning. The displayed quantities remain authoritative even when consumption exceeds capacity.

## Authorization and transport

`BeakClient.summary(spec)` calls `POST /api/{table}/summary`. Field visibility checks cover grouping fields, sum fields and every base or measure predicate, including relationship predicates. Row policy and soft-delete scope apply to every measure. Applications never need to assemble SQL, fetch every record, or aggregate a paginated response.

See Foodio's [order overview](https://github.com/SimonErich/beak/blob/main/examples/foodio-adminpanel/lib/resources/orders/order_overview.dart) for conditional statuses, forecast bars and capacity summaries using one configuration style.

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md)
- [Dashboards](../panel/dashboards.md)
