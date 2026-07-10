import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../overlays/beak_overlays.dart';
import 'beak_panel_config.dart';

/// Opens the panel command bar — a fuzzy-searchable palette (Ctrl/⌘-K) that
/// jumps to any resource or custom page. Commands are derived from the panel
/// config, so every navigable destination is reachable in two keystrokes with
/// no per-app wiring.
void openBeakCommandBar(BuildContext context, BeakPanelConfig config) {
  final GoRouter router = GoRouter.of(context);
  void go(String route) => router.go(route);
  BeakOverlays(context).dialog<void>(
    title: 'Go to',
    builder: (close) => SizedBox(
      width: 640,
      height: 480,
      child: OiCommandBar(
        label: 'Command bar',
        onDismiss: () => close(),
        commands: beakNavigationCommands(config, (route) {
          close();
          go(route);
        }),
      ),
    ),
  );
}

/// Builds one navigation [OiCommand] per resource and in-nav page (plus the
/// dashboard when no page claims `/`), grouped by their sidebar section.
List<OiCommand> beakNavigationCommands(
  BeakPanelConfig config,
  void Function(String route) go,
) {
  final bool hasHome = config.pages.any((page) => page.path == '/');
  return [
    if (!hasHome)
      OiCommand(
        id: 'nav:/',
        label: 'Dashboard',
        icon: OiIcons.layoutDashboard,
        category: 'Navigate',
        onExecute: () => go('/'),
      ),
    for (final resource in config.resources)
      OiCommand(
        id: 'nav:${resource.route}',
        label: resource.effectiveLabel,
        icon: resource.icon.icon,
        category: resource.section ?? 'Resources',
        keywords: const ['open', 'go to'],
        onExecute: () => go(resource.route),
      ),
    for (final page in config.pages)
      if (page.showInNav)
        OiCommand(
          id: 'nav:${page.path}',
          label: page.effectiveLabel,
          icon: page.icon.icon,
          category: page.section ?? 'Pages',
          keywords: const ['open', 'go to'],
          onExecute: () => go(page.path),
        ),
  ];
}
