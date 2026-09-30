import 'package:flutter/widgets.dart';

/// Shares shell-owned page chrome with generated pages without duplicating it.
final class BeakShellPageScope extends InheritedWidget {
  /// Created by the navigation shell around its current routed page.
  const BeakShellPageScope({
    required this.ownsBreadcrumbs,
    required super.child,
    super.key,
  });

  /// Whether the current resource trail is visible in the shell header.
  final bool ownsBreadcrumbs;

  /// Whether a page should leave its breadcrumb presentation to the shell.
  static bool hasBreadcrumbs(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BeakShellPageScope>()
          ?.ownsBreadcrumbs ??
      false;

  @override
  bool updateShouldNotify(BeakShellPageScope oldWidget) =>
      ownsBreadcrumbs != oldWidget.ownsBreadcrumbs;
}
