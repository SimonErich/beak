import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/services/dashboard_charts.dart';
import 'package:obers_ui/obers_ui.dart';

/// The charts gallery — every Beak chart family (area, line, bar, pie, donut)
/// bound to the same seeded analytics tables the dashboard uses, so the whole
/// page is data-driven.
BeakScreen buildChartsScreen() => BeakScreen(
  path: '/charts',
  title: 'Charts',
  icon: const BeakIconToken(OiIcons.barChart2),
  section: 'Showcase',
  body: BeakGridBlock(
    columns: 2,
    gapInPixels: 20,
    children: [
      BeakChartBlock(
        title: 'Revenue (area)',
        type: BeakChartType.area,
        query: const BeakQuerySpec(table: 'time_series_points'),
        map: seriesPoints('sales_revenue'),
      ),
      BeakChartBlock(
        title: 'Orders (line)',
        type: BeakChartType.line,
        query: const BeakQuerySpec(table: 'time_series_points'),
        map: seriesPoints('sales_orders'),
      ),
      BeakChartBlock(
        title: 'Organic audience (bar)',
        type: BeakChartType.bar,
        query: const BeakQuerySpec(table: 'time_series_points'),
        map: seriesPoints('audience_organic'),
      ),
      BeakChartBlock(
        title: 'Social audience (bar)',
        type: BeakChartType.bar,
        query: const BeakQuerySpec(table: 'time_series_points'),
        map: seriesPoints('audience_social'),
      ),
      const BeakChartBlock(
        title: 'Source of purchases (pie)',
        type: BeakChartType.pie,
        query: BeakQuerySpec(table: 'purchase_sources'),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (donut)',
        type: BeakChartType.donut,
        query: BeakQuerySpec(table: 'purchase_sources'),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (radar)',
        type: BeakChartType.radar,
        query: BeakQuerySpec(table: 'purchase_sources'),
        map: purchaseSourcePoints,
      ),
      const BeakChartBlock(
        title: 'Source of purchases (funnel)',
        type: BeakChartType.funnel,
        query: BeakQuerySpec(table: 'purchase_sources'),
        map: purchaseSourcePoints,
      ),
      const BeakBubbleChartBlock(
        title: 'Catalog: price × stock, sized by cost',
        query: BeakQuerySpec(table: 'products'),
        map: productBubblePoints,
      ),
      const BeakCandlestickChartBlock(
        span: BeakSpan(columns: 2),
        title: 'Price history (candlestick)',
        query: BeakQuerySpec(
          table: 'price_candles',
          sorts: [BeakSort('sort_index')],
        ),
        map: priceCandles,
      ),
      const BeakHeatmapChartBlock(
        span: BeakSpan(columns: 2),
        title: 'Orders by weekday & month',
        query: BeakQuerySpec(table: 'activity_heatmap'),
        map: activityHeatCells,
        rowLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ),
    ],
  ),
);
