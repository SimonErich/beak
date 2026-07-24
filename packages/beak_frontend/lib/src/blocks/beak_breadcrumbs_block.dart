part of 'beak_block.dart';

/// A breadcrumb trail; items with a route navigate on tap.
///
/// Renders onto `OiBreadcrumbs`, navigating through the panel's router.
final class BeakBreadcrumbsBlock extends BeakBlock {
  /// Creates a breadcrumb trail over [items].
  const BeakBreadcrumbsBlock({required this.items, super.span});

  /// The trail, root first.
  final List<BeakBreadcrumbBlockItem> items;
}

/// One crumb of a [BeakBreadcrumbsBlock].
@immutable
final class BeakBreadcrumbBlockItem {
  /// Creates a crumb labelled [label], navigating to [route] on tap when
  /// set (the current page's crumb typically has none).
  const BeakBreadcrumbBlockItem({required this.label, this.route});

  /// The crumb text.
  final String label;

  /// Panel route navigated to on tap, when set.
  final String? route;
}
