part of 'beak_block.dart';

/// A compact single-number metric card (count or sum), the composable form
/// of a dashboard stat.
///
/// Renders through the same `BeakStatCard` the flat dashboard uses, so the
/// number is fetched live via the data source.
///
/// ```dart
/// BeakMetricBlock(
///   label: 'Products',
///   aggregate: BeakAggregateSpec.count(table: 'products'),
///   icon: OiIcons.package,
/// );
/// ```
final class BeakMetricBlock extends BeakBlock {
  /// Creates a metric card.
  const BeakMetricBlock({
    required this.label,
    required this.aggregate,
    this.icon,
    this.prefix = '',
    this.suffix = '',
    super.span,
  });

  /// The metric caption.
  final String label;

  /// The count/sum aggregate producing the value.
  final BeakAggregateSpec aggregate;

  /// An optional leading icon.
  final IconData? icon;

  /// A string prefixed to the value (e.g. a currency symbol).
  final String prefix;

  /// A string appended to the value (e.g. a unit).
  final String suffix;
}
