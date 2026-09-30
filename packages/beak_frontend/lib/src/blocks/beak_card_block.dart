part of 'beak_block.dart';

/// Wraps content in an elevated card with an optional header and footer.
///
/// Renders onto `OiCard`.
final class BeakCardBlock extends BeakBlock {
  /// Creates a card around [child].
  const BeakCardBlock({
    required this.child,
    this.title,
    this.subtitle,
    this.headerGapInPixels = 16,
    this.footer,
    super.span,
  });

  /// The card body.
  final BeakBlock child;

  /// Header title text.
  final String? title;

  /// Header subtitle text, shown under [title].
  final String? subtitle;

  /// Space after the header; ignored when no header is declared.
  final double headerGapInPixels;

  /// Footer content, separated from the body.
  final BeakBlock? footer;
}
