part of 'beak_block.dart';

/// A resizable three-pane layout — the backbone of email, chat, and
/// file-manager screens (navigation pane, list pane, detail pane).
///
/// Renders onto `OiThreeColumnLayout`.
final class BeakThreePaneBlock extends BeakBlock {
  /// Creates a three-pane layout.
  const BeakThreePaneBlock({
    required this.label,
    required this.left,
    required this.middle,
    this.right,
    this.leftWidthInPixels = 260,
    this.rightWidthInPixels = 320,
    super.span,
  });

  /// Accessibility label describing the layout (e.g. `'Inbox'`).
  final String label;

  /// The narrow start pane (folders, contacts, filters).
  final BeakBlock left;

  /// The main middle pane.
  final BeakBlock middle;

  /// The optional end pane (detail, preview).
  final BeakBlock? right;

  /// Initial width of the start pane.
  final double leftWidthInPixels;

  /// Initial width of the end pane.
  final double rightWidthInPixels;
}
