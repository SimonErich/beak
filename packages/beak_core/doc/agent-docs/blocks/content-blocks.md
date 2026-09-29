# Content blocks

> Render text, markdown, media, alerts, badges, progress and ratings without data plumbing.

Display blocks hold presentation values such as text, Markdown, images, badges, progress and alerts. They can be nested in any page layout block. Persisted form values should use generated field presentation so locale and semantic metadata stay consistent.

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
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
```

## Continue reading

- [Block reference](../reference/blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
