import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../dashboard/beak_dashboard.dart';
import '../di/beak_locator.dart';
import '../pages/beak_resource_pages.dart';
import 'beak_panel_config.dart';

/// Builds the panel's router: a shell route wrapping the dashboard at `/`
/// and every resource's generated list/create/show/edit pages, a `/login`
/// route outside the shell, and a typed not-found fallback.
///
/// The pages resolve their data source from the Beak locator, registered
/// by `BeakPanel` before the router is created.
GoRouter createBeakRouter(BeakPanelConfig config) => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _BeakShell(config: config, currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => OiResourcePage(
            label: 'Dashboard',
            title: 'Dashboard',
            actions: const [],
            child: BeakDashboard(
              stats: config.dashboardStats,
              charts: config.dashboardCharts,
              dataSource: beakLocator<BeakDataSource>(),
            ),
          ),
        ),
        // Flat routes on purpose: nested routes would keep the list page
        // alive under create/show/edit, so returning to it would show
        // stale data instead of re-querying.
        for (final resource in config.resources) ...[
          GoRoute(
            path: resource.route,
            builder: (context, state) => BeakResourceListPage(
              resource: resource,
              dataSource: beakLocator<BeakDataSource>(),
            ),
          ),
          GoRoute(
            path: '${resource.route}/create',
            builder: (context, state) => BeakResourceCreatePage(
              resource: resource,
              dataSource: beakLocator<BeakDataSource>(),
            ),
          ),
          GoRoute(
            path: '${resource.route}/:id/edit',
            builder: (context, state) => BeakResourceEditPage(
              resource: resource,
              dataSource: beakLocator<BeakDataSource>(),
              recordId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '${resource.route}/:id',
            builder: (context, state) => BeakResourceShowPage(
              resource: resource,
              dataSource: beakLocator<BeakDataSource>(),
              recordId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => OiAuthPage.login(label: config.title),
    ),
  ],
  errorBuilder: (context, state) => OiErrorPage.notFound(
    description: 'No panel page at "${state.uri.path}".',
    actionLabel: 'Back to dashboard',
    onAction: () => context.go('/'),
  ),
);

/// The panel chrome around every routed page: an `OiAppShell` whose
/// navigation is generated from the configured resources.
final class _BeakShell extends StatelessWidget {
  const _BeakShell({
    required this.config,
    required this.currentPath,
    required this.child,
  });

  final BeakPanelConfig config;
  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) => OiAppShell(
    label: config.title,
    title: config.title,
    navigation: [
      const OiNavItem(
        label: 'Dashboard',
        icon: OiIcons.layoutDashboard,
        route: '/',
      ),
      for (final resource in config.resources)
        OiNavItem(
          label: resource.effectiveLabel,
          icon: resource.icon.icon,
          route: resource.route,
        ),
    ],
    currentRoute: currentPath,
    onNavigate: (route) => context.go(route),
    child: child,
  );
}
