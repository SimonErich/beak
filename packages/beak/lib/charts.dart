/// The obers_ui chart widgets, for a dashboard that goes beyond the built-in
/// `BeakChart` blocks.
///
/// Separate from `package:beak/ui.dart` because obers_ui and obers_ui_charts
/// both declare an `OiAnnotationType` — one annotates an image, the other a
/// chart axis — so re-exporting both from one library would make the name
/// ambiguous at every import site.
///
/// ```dart
/// import 'package:beak/charts.dart';
///
/// const chart = OiLineChart(series: [...]);
/// ```
library;

export 'package:obers_ui_charts/obers_ui_charts.dart';
