/// The obers_ui chart widgets, for a chart that goes beyond what a
/// `BeakChartBlock` draws from a query.
///
/// Separate from `package:beak/ui.dart` because obers_ui and obers_ui_charts
/// both declare an `OiAnnotationType` — one annotates an image, the other a
/// chart axis — so re-exporting both from one library would make the name
/// ambiguous at every import site.
///
/// A chart widget joins a screen through a `BeakWidgetBlock`:
///
/// ```dart
/// import 'package:beak/charts.dart';
/// import 'package:beak/panel.dart';
///
/// final revenue = BeakWidgetBlock(
///   (context) => const OiLineChart(
///     label: 'Monthly revenue',
///     series: [
///       OiLineSeries(
///         label: 'Revenue',
///         points: [OiLinePoint(x: 1, y: 4200), OiLinePoint(x: 2, y: 5100)],
///       ),
///     ],
///   ),
/// );
/// ```
library;

export 'package:obers_ui_charts/obers_ui_charts.dart';
