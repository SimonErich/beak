part of 'beak_block.dart';

/// Vertically stacked expandable sections (FAQ-style).
///
/// Renders onto `OiAccordion`.
final class BeakAccordionBlock extends BeakBlock {
  /// Creates an accordion over [items].
  const BeakAccordionBlock({
    required this.items,
    this.allowMultiple = false,
    super.span,
  });

  /// The expandable sections, in display order.
  final List<BeakAccordionBlockItem> items;

  /// Whether several sections may be open at once.
  final bool allowMultiple;
}

/// One expandable section of a [BeakAccordionBlock].
@immutable
final class BeakAccordionBlockItem {
  /// Creates a section.
  const BeakAccordionBlockItem({
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  /// The always-visible section header.
  final String title;

  /// Content revealed when the section expands.
  final BeakBlock content;

  /// Whether the section starts expanded.
  final bool initiallyExpanded;
}
