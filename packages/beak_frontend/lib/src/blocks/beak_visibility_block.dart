part of 'beak_block.dart';

/// Conditionally renders a block subtree without mounting its data requests.
/// Tracks signal reads and re-evaluates on rebuild; server permissions remain
/// authoritative.
final class BeakVisibilityBlock extends BeakBlock {
  /// Guards [child] with the current presentation state.
  const BeakVisibilityBlock({
    required this.visibleWhen,
    required this.child,
    super.span,
  });

  /// Whether to mount the child subtree.
  final bool Function() visibleWhen;

  /// Content to show when admitted.
  final BeakBlock child;
}
