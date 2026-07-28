import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/services/dashboard_charts.dart';

/// The screen mounted at `/`, replacing the generated dashboard.
///
/// The Tocly landing page reproduced from seeded data: four KPI tiles, a sales
/// chart, a source-of-purchases donut, a live-users world map, and three data
/// tables. Nothing is hardcoded.
BeakScreen beakDashboard() => BeakScreen(
  path: '/',
  title: 'Dashboard',
  icon: const BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [_kpis(), _chartsAndDonut(), _mapAndAudience(), _tables()],
  ),
);

// --8<-- [start:kpis]
BeakBlock _kpis() => const BeakGridBlock(
  columns: 4,
  children: [
    BeakKpiBlock(
      title: 'Total earnings',
      value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
      format: BeakKpiFormat.currency,
    ),
    BeakKpiBlock(
      title: 'Total orders',
      value: BeakAggregateSpec.count(table: 'orders'),
    ),
    BeakKpiBlock(
      title: 'Customers',
      value: BeakAggregateSpec.count(table: 'users'),
    ),
    BeakKpiBlock(
      title: 'Products',
      value: BeakAggregateSpec.count(table: 'products'),
    ),
  ],
);
// --8<-- [end:kpis]

BeakBlock _chartsAndDonut() => BeakGridBlock(
  columns: 12,
  children: [
    BeakChartBlock(
      span: const BeakSpan(columns: 8),
      title: 'Sales statistics',
      type: BeakChartType.area,
      query: const BeakQuerySpec(
        table: 'time_series_points',
        sorts: [BeakSort('sort_index')],
        pagination: analyticsPage,
      ),
      map: seriesPoints('sales_revenue'),
    ),
    const BeakChartBlock(
      span: BeakSpan(columns: 4),
      title: 'Source of purchases',
      type: BeakChartType.donut,
      query: BeakQuerySpec(
        table: 'purchase_sources',
        pagination: analyticsPage,
      ),
      map: purchaseSourcePoints,
    ),
  ],
);

BeakBlock _mapAndAudience() => BeakGridBlock(
  columns: 12,
  children: [
    const BeakMapBlock(
      span: BeakSpan(columns: 8),
      title: 'Live users by country',
      query: BeakQuerySpec(table: 'country_stats', pagination: analyticsPage),
      regionCodeField: CountryStatColumns.countryCode,
      valueField: CountryStatColumns.activeUsers,
      valueLabel: 'Active users',
    ),
    BeakChartBlock(
      span: const BeakSpan(columns: 4),
      title: 'Audience metrics',
      type: BeakChartType.bar,
      query: const BeakQuerySpec(
        table: 'time_series_points',
        sorts: [BeakSort('sort_index')],
        pagination: analyticsPage,
      ),
      map: seriesPoints('audience_organic'),
    ),
  ],
);

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
    BeakTableBlock(
      span: BeakSpan(columns: 6),
      title: 'Top customers',
      model: UserModel(),
      initialSpec: BeakQuerySpec(
        table: 'users',
        sorts: [BeakSort('balance', descending: true)],
        pagination: BeakPagination(perPage: 6),
      ),
    ),
    BeakTableBlock(
      span: BeakSpan(columns: 12),
      title: 'Latest transactions',
      model: TransactionModel(),
      initialSpec: BeakQuerySpec(
        table: 'transactions',
        sorts: [BeakSort('occurred_at', descending: true)],
        pagination: BeakPagination(perPage: 6),
      ),
    ),
  ],
);
