import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'models/order.dart';
import 'models/product.dart';

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
    BeakCardBlock(
      span: BeakSpan(columns: 6),
      title: 'Featured products',
      child: BeakTableBlock(
        model: ProductModel(),
        columns: [
          ProductColumns.name,
          ProductColumns.price,
          ProductColumns.stock,
        ],
        baseFilter: BeakFieldFilter(
          column: ProductColumns.featured,
          operator: BeakOperator.eq,
          value: BeakBoolValue(true),
        ),
        initialSpec: BeakQuerySpec(
          table: 'products',
          pagination: BeakPagination(perPage: 5),
        ),
      ),
    ),
  ],
);
