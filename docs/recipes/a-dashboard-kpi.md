---
title: A KPI on the dashboard
description: An aggregate computed in the database, rendered as a headline number.
---

# A KPI on the dashboard

Add `lib/dashboard.dart` declaring `BeakScreen beakDashboard()` and it replaces
the generated page at `/`. A KPI is an aggregate spec plus a title: the number
is computed in the database, and no rows are loaded to produce it.

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
    // ...'Awaiting payment' and 'Out of stock', each a filtered count.
  ],
);
```

## Continue reading

- [Dashboards](../panel/dashboards.md)
