part of 'beak_block.dart';

/// The documented escape hatch: embeds an arbitrary widget subtree where
/// no declarative block fits (mirrors `BeakCustomColumn` on the column
/// side).
///
/// Prefer a typed block whenever one exists — escape hatches trade away
/// the declarative guarantees the rest of the union keeps.
// --8<-- [start:BeakWidgetBlock]
final class BeakWidgetBlock extends BeakBlock {
  /// Creates a block that renders whatever [builder] returns.
  const BeakWidgetBlock(this.builder, {super.span});

  /// Builds the embedded subtree.
  final WidgetBuilder builder;
}

// --8<-- [end:BeakWidgetBlock]
