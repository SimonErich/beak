part of 'beak_block.dart';

/// A horizontal rule, optionally with a centred label.
///
/// Renders onto `OiDivider`.
final class BeakDividerBlock extends BeakBlock {
  /// Creates a divider; [label] centres text in the line when set.
  const BeakDividerBlock({this.label, super.span});

  /// Text centred in the divider line, when set.
  final String? label;
}
