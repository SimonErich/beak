part of 'beak_block.dart';

/// Conditionally renders a block subtree without mounting its data requests.
///
/// [visibleWhen] receives the panel's [BeakPanelAccess] and is evaluated
/// inside a signal-tracking scope, so the subtree appears and disappears while
/// the account's roles change. Server permissions remain authoritative.
///
/// ```dart
/// BeakVisibilityBlock(
///   visibleWhen: (access) => access.has('adminReadSales'),
///   child: BeakMetricBlock(
///     label: 'Orders',
///     aggregate: const OrderModel().count(),
///   ),
/// );
/// ```
final class BeakVisibilityBlock extends BeakBlock {
  /// Guards [child] with the current presentation state.
  const BeakVisibilityBlock({
    required this.visibleWhen,
    required this.child,
    super.span,
  });

  /// Whether to mount the child subtree for the account behind the access.
  final bool Function(BeakPanelAccess access) visibleWhen;

  /// Content to show when admitted.
  final BeakBlock child;
}
