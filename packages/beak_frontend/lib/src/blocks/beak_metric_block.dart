part of 'beak_block.dart';

/// A compact single-number metric card: a live aggregate (count, sum or
/// average), optionally compared with a prior period and measured against a
/// target.
///
/// The value is fetched through the panel's data source, so it works over any
/// `BeakDataSource`, including transports without grouped summaries. It
/// refreshes after writes to the aggregated tables, shows a loading state and
/// offers a retry when the request fails. Numbers are formatted by the panel's
/// display policy (`BeakFormatting`) according to [format], followed by an
/// optional [unit]; for grouped figures use [BeakSummaryBlock].
///
/// ```dart
/// BeakGridBlock(
///   minColumnWidthInPixels: 220,
///   children: [
///     BeakMetricBlock(
///       label: 'Orders to fulfill',
///       icon: OiIcons.shoppingCart,
///       aggregate: const OrderModel().count(
///         filter: OrderModel.status.eq(OrderStatus.confirmed),
///       ),
///     ),
///     // A plain quantity with its unit: "1,240 kg".
///     BeakMetricBlock(
///       label: 'Stock on hand',
///       icon: OiIcons.package,
///       aggregate: const ProductModel().sum(ProductModel.weightInKg.column),
///       unit: 'kg',
///     ),
///     // Money stored in cents, compared with last month and a goal.
///     BeakMetricBlock(
///       label: 'Revenue this month',
///       icon: OiIcons.euro,
///       aggregate: const InvoiceModel().sum(
///         InvoiceModel.totalCents.column,
///         filter: InvoiceModel.issuedAt.gte(startOfMonth),
///       ),
///       previous: const InvoiceModel().sum(
///         InvoiceModel.totalCents.column,
///         filter: BeakAndFilter([
///           InvoiceModel.issuedAt.gte(startOfLastMonth),
///           InvoiceModel.issuedAt.lt(startOfMonth),
///         ]),
///       ),
///       target: 5000000,
///       format: BeakValueFormat.currency,
///       minorUnits: true,
///     ),
///   ],
/// );
/// ```
final class BeakMetricBlock extends BeakBlock {
  /// Creates a metric card showing [aggregate], captioned [label].
// --8<-- [start:BeakMetricBlock]
  const BeakMetricBlock({
    required this.label,
    required this.aggregate,
    this.icon,
    this.format = BeakValueFormat.number,
    this.minorUnits = false,
    this.scale = 2,
    this.unit,
    this.previous,
    this.target,
    super.span,
  }) : assert(scale >= 0 && scale <= 12, 'scale must be between 0 and 12'),
       assert(
         format == BeakValueFormat.number ||
             format == BeakValueFormat.currency ||
             format == BeakValueFormat.percent,
         'format must be number, currency or percent',
       );

  /// The metric caption.
// --8<-- [end:BeakMetricBlock]
  final String label;

  /// The aggregate producing the value.
  final BeakAggregateSpec aggregate;

  /// An optional leading icon.
  final IconData? icon;

  /// How the value (and [target]) are displayed: [BeakValueFormat.number],
  /// [BeakValueFormat.currency] in the panel's currency, or
  /// [BeakValueFormat.percent] for a fractional rate. No other format is
  /// accepted.
  final BeakValueFormat format;

  /// Whether the aggregate is in integer minor units such as cents.
  ///
  /// Aggregates return physical storage units, so a sum over a money field
  /// stored in cents sets this to display major units.
  final bool minorUnits;

  /// Decimal places in minor-unit storage (2 for cents, 4 for basis points).
  final int scale;

  /// An optional unit shown after the value and [target], separated by a
  /// space (`'kg'` renders `12 kg`).
  final String? unit;

  /// The prior period's aggregate; when set, the card shows the percentage
  /// change from it to [aggregate].
  final BeakAggregateSpec? previous;

  /// An optional goal in the aggregate's own units, drawn as a progress track.
  final num? target;
}
