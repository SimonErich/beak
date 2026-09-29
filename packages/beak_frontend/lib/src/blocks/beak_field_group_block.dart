part of 'beak_block.dart';

/// A responsive definition grid of several record fields — the terse way to
/// lay out a block of attributes without one [BeakFieldBlock] per field.
/// Each entry renders as a stacked label/value from the enclosing
/// `BeakRecordScope`, which the screen using the block must mount.
final class BeakFieldGroupBlock extends BeakBlock {
  /// Shows [columns] from the scoped record across [columnCount] grid columns.
  const BeakFieldGroupBlock(this.columns, {this.columnCount = 2, super.span});

  /// The columns to display, in order.
  final List<BeakColumn> columns;

  /// The number of grid columns the fields flow across.
  final int columnCount;
}
