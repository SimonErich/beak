part of 'beak_block.dart';

/// A tab bar whose selected tab's content renders below it.
///
/// Renders onto `OiTabs`; selection state lives in the host.
final class BeakTabsBlock extends BeakBlock {
  /// Creates a tabbed region over [tabs].
  ///
  /// An empty list renders nothing, and an [initialIndex] past the last tab
  /// selects the last one.
  const BeakTabsBlock({required this.tabs, this.initialIndex = 0, super.span});

  /// The tabs, in display order.
  final List<BeakTabBlockItem> tabs;

  /// Index of the tab selected on first build.
  final int initialIndex;
}

/// One tab of a [BeakTabsBlock]: a label (and optional icon) paired with
/// the content shown while it is selected.
@immutable
final class BeakTabBlockItem {
  /// Creates a tab.
  const BeakTabBlockItem({
    required this.label,
    required this.content,
    this.icon,
  });

  /// The tab label.
  final String label;

  /// Icon shown before the label.
  final IconData? icon;

  /// Content rendered while this tab is selected.
  final BeakBlock content;
}
