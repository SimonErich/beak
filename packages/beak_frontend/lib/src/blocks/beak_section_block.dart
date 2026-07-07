part of 'beak_block.dart';

/// Groups content under a titled section heading.
///
/// Renders a heading (and optional description) above the child inside an
/// `OiSection`.
final class BeakSectionBlock extends BeakBlock {
  /// Creates a section around [child].
  const BeakSectionBlock({
    required this.title,
    required this.child,
    this.description,
    super.span,
  });

  /// The section heading.
  final String title;

  /// Supporting copy under the heading.
  final String? description;

  /// The section body.
  final BeakBlock child;
}
