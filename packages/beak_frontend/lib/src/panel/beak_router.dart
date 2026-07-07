import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../dashboard/beak_dashboard.dart';
import '../di/beak_locator.dart';
import '../pages/beak_resource_pages.dart';
import '../pages/beak_screen_view.dart';
import 'beak_auth_config.dart';
import 'beak_maintenance_config.dart';
import 'beak_panel_config.dart';
import 'beak_theme_controller.dart';

/// Builds the panel's router from [config]: a shell route wrapping the
/// dashboard at `/`, every resource's generated list/create/show/edit pages,
/// and every custom [BeakPage]; plus auth, error, and maintenance routes
/// mounted outside the shell.
///
/// [BeakPanel] calls this after [registerBeakDependencies], so the pages
/// resolve their [BeakDataSource] from [beakLocator] on their first frame.
/// Resource routes are intentionally flat rather than nested: nesting would
/// keep a list page alive under its create/show/edit children, so returning
/// to the list would show stale rows instead of re-querying.
GoRouter createBeakRouter(BeakPanelConfig config) => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _BeakShell(config: config, currentPath: state.uri.path, child: child),
      routes: [
        // The built-in stats/charts dashboard is mounted only when no custom
        // page claims `/`; a `BeakScreen(path: '/')` replaces it wholesale.
        if (!_hasHomePage(config))
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
        for (final screen in config.pages)
          GoRoute(
            path: screen.path,
            builder: (context, state) => BeakScreenView(screen: screen),
          ),
      ],
    ),
    ..._authRoutes(config),
    ..._maintenanceRoutes(config.maintenance),
    ..._errorRoutes(),
  ],
  errorBuilder: (context, state) => OiErrorPage.notFound(
    description: 'No panel page at "${state.uri.path}".',
    actionLabel: 'Back to dashboard',
    onAction: () => context.go('/'),
  ),
);

/// Whether a custom page claims the home route `/`, in which case it
/// replaces the built-in dashboard.
bool _hasHomePage(BeakPanelConfig config) =>
    config.pages.any((screen) => screen.path == '/');

List<RouteBase> _authRoutes(BeakPanelConfig config) {
  final BeakAuthConfig? auth = config.auth;
  return [
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          OiAuthPage.login(label: config.title, onLogin: auth?.onLogin),
    ),
    if (auth != null && auth.register)
      GoRoute(
        path: '/register',
        builder: (context, state) => OiAuthPage.register(
          label: config.title,
          onRegister: auth.onRegister,
        ),
      ),
    if (auth != null && auth.recover)
      GoRoute(
        path: '/recover',
        builder: (context, state) => OiAuthPage(
          label: config.title,
          initialMode: OiAuthMode.forgotPassword,
          onForgotPassword: auth.onRecover,
        ),
      ),
  ];
}

List<RouteBase> _maintenanceRoutes(BeakMaintenanceConfig? maintenance) {
  if (maintenance == null) {
    return const [];
  }
  return [
    GoRoute(
      path: '/maintenance',
      builder: (context, state) => OiMaintenancePage(
        label: maintenance.maintenanceTitle,
        title: maintenance.maintenanceTitle,
        description: maintenance.maintenanceDescription,
        estimatedReturn: maintenance.estimatedReturn,
        showCountdown: maintenance.estimatedReturn != null,
      ),
    ),
    GoRoute(
      path: '/coming-soon',
      builder: (context, state) => OiMaintenancePage(
        label: maintenance.comingSoonTitle,
        title: maintenance.comingSoonTitle,
        description: maintenance.comingSoonDescription,
        estimatedReturn: maintenance.launchAt,
        showCountdown: maintenance.launchAt != null,
      ),
    ),
  ];
}

List<RouteBase> _errorRoutes() => [
  GoRoute(
    path: '/403',
    builder: (context, state) => OiErrorPage.forbidden(
      actionLabel: 'Back to dashboard',
      onAction: () => context.go('/'),
    ),
  ),
  GoRoute(
    path: '/500',
    builder: (context, state) => OiErrorPage.serverError(
      actionLabel: 'Back to dashboard',
      onAction: () => context.go('/'),
    ),
  ),
];

/// The panel chrome around every routed page: an `OiAppShell` whose
/// navigation is generated from the configured resources and pages, grouped
/// by their optional sections, with a live theme toggle in the top bar.
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
  Widget build(BuildContext context) {
    final themeController = beakLocator<BeakThemeController>();
    return OiAppShell(
      label: config.title,
      title: config.title,
      sidebarCollapsible: config.sidebarCollapsible,
      sidebarDefaultCollapsed: config.sidebarDefaultCollapsed,
      currentRoute: currentPath,
      onNavigate: (route) => context.go(route),
      actions: [
        // Listens directly to the controller: go_router preserves the shell
        // across navigations, so it would not otherwise see mode changes.
        ValueListenableBuilder<OiThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) => OiThemeToggle(
            currentMode: mode,
            onModeChange: (next) => themeController.value = next,
          ),
        ),
      ],
      navigation: [
        if (!_hasHomePage(config))
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
            section: resource.section,
          ),
        for (final screen in config.pages)
          if (screen.showInNav)
            OiNavItem(
              label: screen.effectiveLabel,
              icon: screen.icon.icon,
              route: screen.path,
              section: screen.section,
            ),
      ],
      child: child,
    );
  }
}
