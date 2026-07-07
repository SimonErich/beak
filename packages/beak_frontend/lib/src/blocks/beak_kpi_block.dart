part of 'beak_block.dart';

/// How a [BeakKpiBlock] formats its value and delta.
enum BeakKpiFormat {
  /// A plain number with grouping (e.g. `34,123`).
  number,

  /// A currency amount prefixed with the block's symbol (e.g. `$34,123`).
  currency,

  /// A percentage, the value multiplied by 100 with a `%` suffix.
  percent,
}

/// A KPI tile: a headline aggregate, an optional prior-period aggregate that
/// drives an up/down delta badge, an icon, and an optional target.
///
/// Renders onto `OiKpiCard`. Both aggregates run through the data source, so
/// the number is always live — never hardcoded.
///
/// ```dart
/// BeakKpiBlock(
///   title: 'Total earnings',
///   value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
///   previous: BeakAggregateSpec.sum(
///     table: 'orders',
///     column: OrderColumns.total,
///     filter: lastMonth,
///   ),
///   format: BeakKpiFormat.currency,
/// );
/// ```
final class BeakKpiBlock extends BeakBlock {
  /// Creates a KPI tile.
  const BeakKpiBlock({
    required this.title,
    required this.value,
    this.previous,
    this.target,
    this.format = BeakKpiFormat.number,
    this.currencySymbol = r'$',
    this.decimals = 0,
    super.span,
  });

  /// The tile heading.
  final String title;

  /// The headline value.
  final BeakAggregateSpec value;

  /// The prior period; when set, drives the delta badge.
  final BeakAggregateSpec? previous;

  /// An optional goal, drawn as a progress track.
  final num? target;

  /// How [value] and the delta are formatted.
  final BeakKpiFormat format;

  /// Currency prefix used when [format] is [BeakKpiFormat.currency].
  final String currencySymbol;

  /// Decimal places shown.
  final int decimals;
}
