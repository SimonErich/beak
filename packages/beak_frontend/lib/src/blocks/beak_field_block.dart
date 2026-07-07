part of 'beak_block.dart';

/// How a [BeakFieldBlock] arranges its label and value.
enum BeakFieldLayout {
  /// Label above the value — the readable default for narrow columns.
  stacked,

  /// Label beside the value — a compact definition row.
  inline,
}

/// A single record field: a label and the current record's value for
/// [column], formatted exactly like the table and default detail view
/// (badges, dates, images, swatches, relations). Resolves the value from the
/// enclosing `BeakRecordScope`, so it is a `const` leaf a detail layout drops
/// into any card, grid, or tab.
final class BeakFieldBlock extends BeakBlock {
  /// Shows [column] from the scoped record.
  const BeakFieldBlock(
    this.column, {
    this.label,
    this.layout = BeakFieldLayout.stacked,
    super.span,
  });

  /// The column to display.
  final BeakColumn column;

  /// A label override; defaults to [BeakColumn.label].
  final String? label;

  /// Whether the label sits above or beside the value.
  final BeakFieldLayout layout;
}
