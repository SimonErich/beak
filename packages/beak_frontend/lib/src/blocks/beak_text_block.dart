part of 'beak_block.dart';

/// Typographic variants a [BeakTextBlock] can render as.
enum BeakTextVariant {
  /// Hero display text.
  display,

  /// Page-level heading.
  h1,

  /// Section heading.
  h2,

  /// Sub-section heading.
  h3,

  /// Minor heading.
  h4,

  /// Regular body copy.
  body,

  /// Emphasized body copy.
  bodyStrong,

  /// De-emphasized small text.
  small,

  /// Caption / hint text.
  caption,
}

/// A run of themed text.
///
/// Renders onto the matching `OiLabel` variant.
final class BeakTextBlock extends BeakBlock {
  /// Creates a text block showing [text].
  const BeakTextBlock(
    this.text, {
    this.variant = BeakTextVariant.body,
    super.span,
  });

  /// The text to show.
  final String text;

  /// The typographic variant.
  final BeakTextVariant variant;
}
