import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_panel_config.dart';

/// Builds the panel's router: a shell route wrapping every resource's
/// list/create/show/edit pages (plus the dashboard at `/`), a `/login`
/// route outside the shell, and a typed not-found fallback.
///
/// The pages are `OiResourcePage` scaffolds — Phases 12–14 fill in the
/// table, form, and detail content.
GoRouter createBeakRouter(BeakPanelConfig config) => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _BeakShell(config: config, currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const OiResourcePage(
            label: 'Dashboard',
            title: 'Dashboard',
            actions: [],
            child: OiLabel.body('Dashboard widgets arrive in Phase 14.'),
          ),
        ),
        for (final resource in config.resources)
          GoRoute(
            path: resource.route,
            builder: (context, state) =>
                _resourcePlaceholder(resource, OiResourcePageVariant.list),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => _resourcePlaceholder(
                  resource,
                  OiResourcePageVariant.create,
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => _resourcePlaceholder(
                  resource,
                  OiResourcePageVariant.show,
                  recordId: state.pathParameters['id'],
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => _resourcePlaceholder(
                      resource,
                      OiResourcePageVariant.edit,
                      recordId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
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

OiResourcePage _resourcePlaceholder(
  BeakResource resource,
  OiResourcePageVariant variant, {
  String? recordId,
}) => OiResourcePage(
  label: resource.effectiveLabel,
  title: recordId == null
      ? resource.effectiveLabel
      : '${resource.effectiveLabel} $recordId',
  variant: variant,
  child: OiLabel.body(
    'The ${resource.effectiveLabel} ${variant.name} page arrives in '
    'Phases 12–14.',
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
