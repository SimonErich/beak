import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/services/dashboard_charts.dart';
import 'package:beak/ui.dart';

/// The charts gallery — every Beak chart family (area, line, bar, pie, donut)
/// bound to the same seeded analytics tables the dashboard uses, so the whole
/// page is data-driven. Two aggregate metrics head it, because a chart shows
/// a shape and a number answers "how many".
BeakScreen buildChartsScreen() => BeakScreen(
  path: '/charts',
  title: 'Charts',
  icon: const BeakIconToken(OiIcons.barChart2),
  section: 'Showcase',
  body: BeakGridBlock(
    columns: 2,
    gapInPixels: 20,
    children: [
      const BeakMetricBlock(
        label: 'Orders placed',
        aggregate: BeakAggregateSpec.count(table: 'orders'),
        icon: OiIcons.shoppingCart,
      ),
      const BeakMetricBlock(
        label: 'Revenue booked',
        aggregate: BeakAggregateSpec.sum(
          table: 'orders',
          column: OrderColumns.total,
        ),
        prefix: r'$',
        icon: OiIcons.creditCard,
      ),
      BeakChartBlock(
        title: 'Revenue (area)',
        type: BeakChartType.area,
        query: const BeakQuerySpec(
          table: 'time_series_points',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: seriesPoints('sales_revenue'),
      ),
      BeakChartBlock(
        title: 'Orders (line)',
        type: BeakChartType.line,
        query: const BeakQuerySpec(
          table: 'time_series_points',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: seriesPoints('sales_orders'),
      ),
      BeakChartBlock(
        title: 'Organic audience (bar)',
        type: BeakChartType.bar,
        query: const BeakQuerySpec(
          table: 'time_series_points',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: seriesPoints('audience_organic'),
      ),
      BeakChartBlock(
        title: 'Social audience (bar)',
        type: BeakChartType.bar,
        query: const BeakQuerySpec(
          table: 'time_series_points',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: seriesPoints('audience_social'),
      ),
      const BeakChartBlock(
        title: 'Source of purchases (pie)',
        type: BeakChartType.pie,
        query: BeakQuerySpec(
          table: 'purchase_sources',
          pagination: analyticsPage,
        ),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (donut)',
        type: BeakChartType.donut,
        query: BeakQuerySpec(
          table: 'purchase_sources',
          pagination: analyticsPage,
        ),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (radar)',
        type: BeakChartType.radar,
        query: BeakQuerySpec(
          table: 'purchase_sources',
          pagination: analyticsPage,
        ),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (funnel)',
        type: BeakChartType.funnel,
        query: BeakQuerySpec(
          table: 'purchase_sources',
          pagination: analyticsPage,
        ),
        map: purchaseSourcePoints,
      ),
      const BeakBubbleChartBlock(
        title: 'Catalog: price × stock, sized by cost',
        query: BeakQuerySpec(table: 'products', pagination: analyticsPage),
        map: productBubblePoints,
      ),
      const BeakCandlestickChartBlock(
        span: BeakSpan(columns: 2),
        title: 'Price history (candlestick)',
        query: BeakQuerySpec(
          table: 'price_candles',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: priceCandles,
      ),
      const BeakHeatmapChartBlock(
        span: BeakSpan(columns: 2),
        title: 'Orders by weekday & month',
        query: BeakQuerySpec(
          table: 'activity_heatmap',
          sorts: [BeakSort('sort_index')],
          pagination: analyticsPage,
        ),
        map: activityHeatCells,
        rowLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
    ],
  ),
);
