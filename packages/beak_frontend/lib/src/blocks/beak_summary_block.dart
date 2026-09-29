part of 'beak_block.dart';

/// Population inherited by a summary inside a composed resource list.
enum BeakSummaryScope {
  /// Permanent, preset, user filters and search; never table pagination.
  active,

  /// Permanent application scope, independent of the selected preset.
  base,

  /// The summary's own explicit query, useful for a different model.
  standalone,
}

/// Rendering of authoritative summary rows.
enum BeakSummaryPresentation {
  /// One formatted card value per measure.
  metrics,

  /// Joined inline values for a compact operational overview.
  strip,

  /// Grouped multi-series bars.
  bar,

  /// One measure split across groups.
  donut,

  /// Compact grouped rows with all configured measures.
  table,

  /// Booked quantities against the configured capacity measure.
  capacity,
}

/// Per-group presentation, independent of the authoritative measure values.
final class BeakSummaryGroupStyle {
  /// Defines chart labels and non-color forecast differentiation.
  const BeakSummaryGroupStyle({
    this.label,
    this.section,
    this.color,
    this.hatched = false,
    this.emphasized = false,
  });

  /// Emphasizes this category and displays its value above the bar.
  final bool emphasized;

  /// Optional concise label, for example a day number.
  final String? label;

  /// Optional second-level axis label, for example a calendar week.
  final String? section;

  /// Semantic group color, shared by the chart and its legend.
  final Color? color;

  /// Differentiates planned quantities using a diagonal pattern.
  final bool hatched;
}

/// A key explaining semantic colors and forecast patterns in a summary.
final class BeakSummaryLegend {
  /// Declares presentation independently of the summary's measured values.
  const BeakSummaryLegend({
    required this.label,
    required this.color,
    this.hatched = false,
  });

  /// Human-readable meaning.
  final String label;

  /// Marker color from the application theme.
  final Color color;

  /// Diagonal pattern, also used by forecast bars and free capacity tracks.
  final bool hatched;
}

/// Typed measure pairing for utilization and capacity displays.
final class BeakSummaryCapacity {
  /// Both measures must be the objects declared in the summary query.
  const BeakSummaryCapacity({
    required this.used,
    required this.total,
    this.warningThreshold = .95,
    this.warning,
    this.warningColor,
    this.trackHeight = 6,
  });

  /// Booked/consumed measure.
  final BeakSummaryMeasure used;

  /// Maximum available measure.
  final BeakSummaryMeasure total;

  /// Utilization ratio at which the warning treatment is applied.
  final double warningThreshold;

  /// Optional chart color for near-capacity tracks.
  final Color? warningColor;

  /// Height of the shared capacity track in logical pixels.
  final double trackHeight;

  /// Optional explanation evaluated against the authoritative grouped row.
  final String? Function(BeakSummaryRow row)? warning;
}

/// The display of a typed summary measure, retaining its storage units.
final class BeakSummaryValue {
  /// Counts use number formatting; monetary measures may declare minor units.
  const BeakSummaryValue({
    required this.measure,
    required this.label,
    this.format = BeakValueFormat.number,
    this.minorUnits = false,
    this.scale = 2,
    this.color,
    this.icon,
    this.iconColor,
  });

  /// Same measure object declared in the summary query.
  final BeakSummaryMeasure measure;

  /// Human-readable label.
  final String label;

  /// Panel display formatting.
  final BeakValueFormat format;

  /// Whether integer values store minor currency units.
  final bool minorUnits;

  /// Number of decimal places in minor-unit storage.
  final int scale;

  /// Optional series color, also used for conditional metric donut segments.
  final Color? color;

  /// Optional semantic marker in compact operational metric strips.
  final IconData? icon;

  /// Theme color of the metric marker; omitted values use muted text.
  final BeakColor? iconColor;
}

/// A bounded server summary, automatically bound to the current list scope.
final class BeakSummaryBlock extends BeakBlock {
  /// No application fetching, error state or aggregate mapping is required.
  const BeakSummaryBlock({
    required this.title,
    required this.query,
    required this.values,
    this.groupField,
    this.presentation = BeakSummaryPresentation.metrics,
    this.scope = BeakSummaryScope.active,
    this.heightInPixels = 240,
    this.subtitle,
    this.footer,
    this.groupStyle,
    this.groupOrder = const [],
    this.showTableToggle = false,
    this.showValues = false,
    this.centerLabel,
    this.maximum,
    this.divisions,
    this.capacity,
    this.legend = const [],
    super.span,
  });

  /// Optional chart key displayed above the data.
  final List<BeakSummaryLegend> legend;

  /// Accessible panel and chart title.
  final String title;

  /// Whole-population query, independent of the visible table page.
  final BeakSummarySpec query;

  /// Ordered measures and their formats.
  final List<BeakSummaryValue> values;

  /// Optional typed group metadata for enum/date formatting.
  final BeakScalarField<Object>? groupField;

  /// Chart or summary presentation.
  final BeakSummaryPresentation presentation;

  /// Which surrounding query constraints are inherited.
  final BeakSummaryScope scope;

  /// Bounded chart height in logical pixels.
  final double heightInPixels;

  /// Text below the heading.
  final String? subtitle;

  /// Contextual footer computed from the full summary, never the visible page.
  final String Function(BeakSummaryResult summary)? footer;

  /// Pure group presentation; it cannot change counts or query scope.
  final BeakSummaryGroupStyle Function(BeakSummaryRow row)? groupStyle;

  /// Raw group values in display order; unspecified groups follow server order.
  final List<Object> groupOrder;

  /// Accessible chart/table switch over the same loaded result.
  final bool showTableToggle;

  /// Shows measure values above bars.
  final bool showValues;

  /// Label below the authoritative first-measure total in a donut center.
  final String? centerLabel;

  /// Optional fixed value-axis maximum and number of divisions.
  final double? maximum;

  /// Number of equal divisions on the value axis.
  final int? divisions;

  /// Required when [presentation] is [BeakSummaryPresentation.capacity].
  final BeakSummaryCapacity? capacity;
}
