part of 'beak_block.dart';

/// Rendered Markdown — long-form content like terms, changelogs, and
/// starter copy.
///
/// Renders onto `OiMarkdown`.
final class BeakMarkdownBlock extends BeakBlock {
  /// Creates a markdown block over [source].
  const BeakMarkdownBlock(this.source, {super.span});

  /// The raw Markdown source.
  final String source;
}
