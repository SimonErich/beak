import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:signals/signals_flutter.dart';

import '../auth/beak_auth_page.dart';
import '../actions/beak_model_action_runner.dart';
import '../actions/beak_pending_actions.dart';
import '../auth/beak_auth_adapter.dart';
import '../auth/beak_auth_gate.dart';
import '../auth/beak_session_store.dart';
import '../auth/beak_logout_button.dart';
import '../localization/beak_localizations.dart';
import '../di/beak_locator.dart';
import '../pages/beak_resource_pages.dart';
import '../form/beak_configured_form.dart';
import 'beak_resource_screen.dart';
import 'beak_routes.dart';
import 'beak_navigation.dart';
import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../pages/beak_screen_view.dart';
import '../query/beak_query_controller.dart';
import 'beak_auth_config.dart';
import 'beak_command_bar.dart';
import 'beak_maintenance_config.dart';
import 'beak_notifications.dart';
import 'beak_panel_config.dart';
import 'beak_theme_controller.dart';
import 'beak_back_button.dart';
import 'beak_shell_page_scope.dart';

/// Builds the panel's router from [config]: a shell route wrapping every
/// resource's generated list/create/show/edit pages and every custom
/// [BeakScreen]; plus auth, error, and maintenance routes mounted outside the
/// shell. `/` is the screen that claims it, and otherwise redirects to the
/// panel's home destination ([BeakPanelConfig.home], then the first visible
/// navigation destination).
///
/// [BeakPanel] calls this after [registerBeakDependencies], so the pages
/// resolve their [BeakDataSource] from [beakLocator] on their first frame.
/// Resource routes are intentionally flat rather than nested: nesting would
/// keep a list page alive under its create/show/edit children, so returning
/// to the list would show stale rows instead of re-querying.
GoRouter createBeakRouter(
  BeakPanelConfig config, {
  BeakAuthRouterRefresh? authRefresh,
}) => GoRouter(
  refreshListenable: authRefresh,
  redirect: (_, state) => authRefresh?.redirect(state.uri.path),
  routes: [
    ...beakPanelRoutes(config),
    ...beakAuthRoutes(config),
    ..._maintenanceRoutes(config.maintenance),
    ..._errorRoutes(),
  ],
  errorBuilder: (context, state) => OiErrorPage.notFound(
    description: BeakLocalizations.of(context).notFoundPath(state.uri.path),
    actionLabel: BeakLocalizations.of(context).backToDashboard,
    onAction: () => context.go('/'),
  ),
);

/// Routes and shell for embedding Beak in a host application's router.
///
/// The host registers Beak dependencies, owns the app widget and authentication,
/// and can put these routes inside its own guarded shell. No second router or
/// authentication routes are created.
List<RouteBase> beakPanelRoutes(BeakPanelConfig config) => [
  ShellRoute(
    builder: (context, state, child) => _watchAuth(context, config, (context) {
      final shell = _fullScreenRoute(config, state.uri.path)
          ? child
          : _BeakShell(
              config: config,
              currentPath: state.uri.path,
              child: child,
            );
      return config.auth == null
          ? shell
          : BeakAuthGate(
              adapter:
                  config.auth?.adapter ??
                  beakDependencies(context)<BeakSessionStore>(),
              child: shell,
            );
    }),
    routes: [
      // `/` is claimed by a screen, or forwards to the panel's home; sign-in
      // and the error pages' back actions rely on it landing somewhere real.
      if (!_hasHomePage(config))
        if (_homeLocation(config) case final String home)
          GoRoute(path: '/', redirect: (_, _) => home),
      // Flat routes on purpose: nested routes would keep the list page
      // alive under create/show/edit, so returning to it would show
      // stale data instead of re-querying.
      for (final resource in config.resources) ...[
        GoRoute(
          path: resource.route,
          onExit: (context, state) => beakConfirmFormExit(context),
          redirect: (_, _) => resource.isVisible ? null : '/403',
          builder: (context, state) => _watchAuth(
            context,
            config,
            (context) =>
                _customResourceScreen(
                  resource.screenFor(BeakScreenRole.list),
                  context,
                  null,
                ) ??
                BeakResourceListPage(
                  resource: resource,
                  dataSource: beakDependencies(context)<BeakDataSource>(),
                ),
          ),
        ),
        GoRoute(
          path: '${resource.route}/create',
          onExit: (context, state) => beakConfirmFormExit(context),
          redirect: (_, _) => resource.allowsCreate ? null : '/403',
          builder: (context, state) => _watchAuth(
            context,
            config,
            (context) =>
                _customResourceScreen(
                  resource.screenFor(BeakScreenRole.create),
                  context,
                  null,
                ) ??
                BeakResourceCreatePage(
                  resource: resource,
                  dataSource: beakDependencies(context)<BeakDataSource>(),
                ),
          ),
        ),
        GoRoute(
          path: '${resource.route}/:id/edit',
          onExit: (context, state) => beakConfirmFormExit(context),
          redirect: (_, _) => resource.allowsEdit ? null : '/403',
          builder: (context, state) => _watchAuth(
            context,
            config,
            (context) =>
                _customResourceScreen(
                  resource.screenFor(BeakScreenRole.edit),
                  context,
                  state.pathParameters['id'],
                ) ??
                BeakResourceEditPage(
                  resource: resource,
                  dataSource: beakDependencies(context)<BeakDataSource>(),
                  recordId: state.pathParameters['id'] ?? '',
                ),
          ),
        ),
        GoRoute(
          path: '${resource.route}/:id',
          onExit: (context, state) => beakConfirmFormExit(context),
          redirect: (_, _) => resource.isVisible ? null : '/403',
          builder: (context, state) => _watchAuth(
            context,
            config,
            (context) =>
                _customResourceScreen(
                  resource.screenFor(BeakScreenRole.read),
                  context,
                  state.pathParameters['id'],
                ) ??
                BeakResourceShowPage(
                  resource: resource,
                  dataSource: beakDependencies(context)<BeakDataSource>(),
                  recordId: state.pathParameters['id'] ?? '',
                ),
          ),
        ),
      ],
      for (final screen in config.pages)
        GoRoute(
          path: screen.path,
          builder: (context, state) => _watchAuth(
            context,
            config,
            (context) => BeakScreenView(screen: screen),
          ),
        ),
    ],
  ),
];

Widget? _customResourceScreen(
  BeakResourceScreen? screen,
  BuildContext context,
  Object? id,
) => switch (screen) {
  final BeakCustomResourceScreen custom => custom.builder(context, id),
  _ => null,
};

// GoRouter refresh reevaluates redirects but can retain the same route child.
// Preserve controllers during a same-identity permission refresh, but reset
// routed state when the principal changes. A shell key alone is insufficient:
// the nested Navigator owns a global key and can otherwise reparent old pages.
Widget _watchAuth(
  BuildContext context,
  BeakPanelConfig config,
  WidgetBuilder builder,
) {
  final auth = config.auth;
  if (auth == null) return Builder(builder: builder);
  final adapter = auth.adapter ?? beakDependencies(context)<BeakSessionStore>();
  return Watch((context) {
    final identity = switch (adapter.state.value) {
      BeakAuthAuthenticated(:final identity) => identity.id,
      _ => null,
    };
    return KeyedSubtree(key: ValueKey(identity), child: builder(context));
  });
}

/// Whether a custom page claims the home route `/`.
bool _hasHomePage(BeakPanelConfig config) =>
    config.pages.any((screen) => screen.path == '/');

/// Where `/` forwards when no page claims it: [BeakPanelConfig.home] while it
/// is visible, and otherwise the first visible navigation destination in the
/// order the shell lists them. `null` when the panel has nothing to show.
String? _homeLocation(BeakPanelConfig config) {
  final resources = {
    for (final resource in config.resources) resource.model.table: resource,
  };
  bool visible(BeakNavigationItem item) =>
      item.model == null || (resources[item.model!.table]?.isVisible ?? false);
  final home = config.home;
  if (home != null) {
    final reachable = switch (home) {
      final BeakResource resource => resource.isVisible,
      _ => true,
    };
    if (reachable) return home.location;
  }
  final sections = config.navigation?.sections ?? const [];
  for (final section in [
    ...sections.where((section) => !section.bottom),
    ...sections.where((section) => section.bottom),
  ]) {
    for (final item in section.items) {
      if (visible(item)) return item.route;
    }
  }
  for (final resource in config.navigationResources) {
    if (resource.isVisible) return resource.route;
  }
  for (final screen in config.pages) {
    if (screen.showInNav) return screen.path;
  }
  return null;
}

/// Authentication routes for standalone or host-router composition.
///
/// Mount outside a loading gate so sign-in permission resolution cannot unmount
/// the form awaiting its outcome. Registration/recovery require explicit opt-in
/// and a backend capability; direct URLs cannot enable an absent workflow.
List<RouteBase> beakAuthRoutes(BeakPanelConfig config) {
  final auth = config.auth ?? const BeakAuthConfig();
  GoRoute route(String path, BeakAuthMode mode) => GoRoute(
    path: path,
    builder: (context, state) => BeakAuthPage(
      key: ValueKey(mode),
      title: config.title,
      config: auth,
      mode: mode,
      onSignedIn: () => context.go(mode == BeakAuthMode.login ? '/' : '/login'),
      onModeChanged: (next) => context.go(switch (next) {
        BeakAuthMode.login => '/login',
        BeakAuthMode.register => '/register',
        BeakAuthMode.recover => '/recover',
      }),
    ),
  );
  return [
    route('/login', BeakAuthMode.login),
    if (auth.allowsRegistration) route('/register', BeakAuthMode.register),
    if (auth.allowsRecovery) route('/recover', BeakAuthMode.recover),
    GoRoute(
      path: '/lock',
      builder: (context, state) => OiAuthPage.lock(
        label: config.title,
        userName: auth.lockUserName ?? config.title,
        onUnlock: (password) async {
          final unlocked =
              await (auth.onUnlock?.call(password) ??
                  Future<bool>.value(false));
          if (unlocked && context.mounted) context.go('/');
          return unlocked;
        },
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
      actionLabel: BeakLocalizations.of(context).backToDashboard,
      onAction: () => context.go('/'),
    ),
  ),
  GoRoute(
    path: '/500',
    builder: (context, state) => OiErrorPage.serverError(
      actionLabel: BeakLocalizations.of(context).backToDashboard,
      onAction: () => context.go('/'),
    ),
  ),
];

/// The panel chrome around every routed page: an `OiAppShell` whose
/// navigation is generated from the configured resources and pages, grouped
/// by their optional sections, with a live theme toggle in the top bar.
final class _BeakShell extends HookWidget {
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
    final resources = {
      for (final resource in config.resources) resource.model.table: resource,
    };
    bool visible(BeakNavigationItem item) =>
        item.model == null ||
        (resources[item.model!.table]?.isVisible ?? false);
    final sections =
        config.navigation?.sections
            .where((section) => section.items.any(visible))
            .toList() ??
        [];
    final section =
        sections
            .where(
              (section) => section.items.any((item) {
                final path = Uri.parse(item.route).path;
                return currentPath == path || currentPath.startsWith('$path/');
              }),
            )
            .firstOrNull ??
        sections.firstOrNull;
    final recordResource = config.resources
        .where(
          (resource) =>
              currentPath.startsWith('${resource.route}/') &&
              !currentPath.endsWith('/create'),
        )
        .firstOrNull;
    final recordId = recordResource == null
        ? null
        : Uri.decodeComponent(
            currentPath
                .substring(recordResource.route.length + 1)
                .split('/')
                .first,
          );
    final currentRecord = useState<BeakRecord?>(null);
    final source = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(
      source,
      table: recordResource?.model.table ?? '',
    );
    useEffect(() {
      currentRecord.value = null;
      if (recordResource == null ||
          recordId == null ||
          config.navigation == null) {
        return null;
      }
      var active = true;
      BeakResourceRepository(
        source,
      ).getOne(recordResource.model.table, recordId).then((result) {
        if (active) {
          if (result case BeakOk(:final value)) currentRecord.value = value;
        }
      });
      return () => active = false;
    }, [source, recordResource, recordId, revision]);
    final countRevision = useBeakDataRevision(source);
    final navigationCounts = useState(const <String, int?>{});
    useEffect(() {
      var active = true;
      navigationCounts.value = const {};
      final entries =
          section?.items
              .where((item) => item.showCount && visible(item))
              .toList() ??
          const <BeakNavigationItem>[];
      Future.wait(
        entries.map((item) async {
          final resource = resources[item.model!.table]!;
          final screen = resource.screenFor(BeakScreenRole.list);
          final list = screen is BeakTableScreen ? screen : null;
          final definition = list?.definition;
          final result = await BeakResourceRepository(source).run(() async {
            final controller = BeakQueryController(
              model: resource.model,
              base: list?.query,
              presets: definition?.presets ?? const [],
              initial: BeakQueryState(
                preset: item.preset ?? definition?.initialPreset,
              ),
            );
            try {
              final query = controller.query.paginate(page: 1, perPage: 1);
              return (await source.query(query)).total;
            } finally {
              controller.dispose();
            }
          });
          return MapEntry(item.route, switch (result) {
            BeakOk(:final value) => value,
            BeakErr() => null,
          });
        }),
      ).then((counts) {
        if (active) navigationCounts.value = Map.fromEntries(counts);
      });
      return () => active = false;
    }, [source, section, config.resources, countRevision]);
    final recordLabel = currentRecord.value == null || recordResource == null
        ? recordId ?? ''
        : currentRecord.value![recordResource.model.displayColumnKey]?.raw
                  ?.toString() ??
              recordId ??
              '';
    final recordMonospace =
        section?.items.any(
          (item) =>
              item.model?.table == recordResource?.model.table &&
              item.recordLabelMonospace,
        ) ??
        false;
    OiNavItem navItem(BeakNavigationItem item) {
      final resource = resources[item.model?.table];
      return OiNavItem(
        label: item.label ?? resource?.effectiveNavigationTitle ?? '',
        icon: item.icon ?? resource?.icon.icon ?? OiIcons.layoutDashboard,
        route: item.route,
        badge: item.showCount
            ? navigationCounts.value[item.route]?.toString() ?? '—'
            : null,
        children:
            currentRecord.value != null &&
                recordResource == resource &&
                item.preset == null &&
                (config.navigation?.showCurrentRecord ?? false)
            ? [
                OiNavItem(
                  label: recordLabel,
                  contextChild: config.navigation?.currentRecordBranch ?? false,
                  monospace: item.recordLabelMonospace,
                  icon: resource!.icon.icon,
                  route: '${resource.route}/$recordId',
                ),
              ]
            : null,
      );
    }

    final themeController = beakDependencies(context)<BeakThemeController>();
    final workspaceCreate = config.navigation?.showCreateAction == true
        ? section?.items
              .where((item) => item.model != null && visible(item))
              .map((item) => resources[item.model!.table])
              .whereType<BeakResource>()
              .where((resource) => resource.allowsCreate)
              .firstOrNull
        : null;
    void openCommandBar() => openBeakCommandBar(context, config);
    final Widget shell = LayoutBuilder(
      builder: (context, constraints) {
        final viewport = MediaQuery.of(context);
        // The panel may occupy a split view narrower than the window. Resolve
        // shell navigation and all descendant breakpoints against its own space.
        final size = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : viewport.size.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : viewport.size.height,
        );
        return MediaQuery(
          data: viewport.copyWith(size: size),
          child: Builder(
            builder: (context) {
              final ownsBreadcrumbs =
                  config.navigation != null &&
                  recordResource != null &&
                  MediaQuery.sizeOf(context).width >= 600;
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                      openCommandBar,
                  const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                      openCommandBar,
                },
                child: Focus(
                  autofocus: true,
                  child: OiAppShell(
                    label: config.title,
                    title:
                        MediaQuery.sizeOf(context).width < 600 ||
                            ownsBreadcrumbs
                        ? null
                        : config.navigation == null
                        ? config.title
                        : recordResource?.effectiveNavigationTitle ??
                              section?.label ??
                              config.title,
                    breadcrumbs: ownsBreadcrumbs
                        ? [
                            OiBreadcrumbItem(
                              label: recordResource.effectiveNavigationTitle,
                              onTap: () => context.go(
                                BeakBackButton.destination(
                                  GoRouterState.of(context).uri,
                                  recordResource.route,
                                ),
                              ),
                            ),
                            OiBreadcrumbItem(
                              label: recordLabel,
                              monospace: recordMonospace,
                            ),
                          ]
                        : null,
                    search: config.navigation?.searchInHeader == true
                        ? SizedBox(
                            width: MediaQuery.sizeOf(context).width < 900
                                ? 180
                                : 360,
                            child: OiSearchTrigger(
                              label:
                                  config.navigation?.searchPlaceholder ??
                                  '${BeakLocalizations.of(context).search} (Ctrl-K)',
                              shortcut:
                                  config.navigation?.searchShortcut ??
                                  const ['meta', 'K'],
                              onPressed: openCommandBar,
                            ),
                          )
                        : null,
                    onSearch: config.navigation?.searchInHeader == true
                        ? openCommandBar
                        : null,
                    searchLabel:
                        config.navigation?.searchPlaceholder ??
                        '${BeakLocalizations.of(context).search} (Ctrl-K)',
                    sidebarCollapsible: config.sidebarCollapsible,
                    sidebarDefaultCollapsed: config.sidebarDefaultCollapsed,
                    primaryNavigation: [
                      for (final section in sections.where(
                        (section) => !section.bottom,
                      ))
                        OiNavItem(
                          label: section.label,
                          icon: section.icon,
                          route: section.items.firstWhere(visible).route,
                        ),
                    ],
                    currentPrimaryRoute: section?.items
                        .firstWhere(visible)
                        .route,
                    onPrimaryNavigate: (route) => context.go(route),
                    primaryLeading: config.navigation?.leading,
                    primaryTrailing: sections.any((section) => section.bottom)
                        ? _BottomNavigation(
                            sections: sections
                                .where((section) => section.bottom)
                                .toList(),
                            current: section,
                            visible: visible,
                          )
                        : null,
                    navigationHeader: section == null
                        ? null
                        : config.navigation?.headerBuilder?.call(
                                context,
                                section.label,
                              ) ??
                              OiSidebarHeader(
                                title: section.label,
                                trailing: workspaceCreate == null
                                    ? null
                                    : OiButton.icon(
                                        icon: OiIcons.plus,
                                        label:
                                            '${BeakLocalizations.of(context).create} in ${section.label}',
                                        size: OiButtonSize.small,
                                        onTap: () => context.go(
                                          BeakRoutes.create(
                                            workspaceCreate.model.table,
                                          ),
                                        ),
                                      ),
                              ),
                    userMenu: config.navigation?.userMenu,
                    navigationFooter: config.navigation?.footer,
                    currentRoute:
                        currentRecord.value != null && recordResource != null
                        ? '${recordResource.route}/$recordId'
                        : section?.items
                                  .where(
                                    (item) =>
                                        item.preset != null &&
                                        item.matches(
                                          GoRouterState.of(context).uri,
                                        ),
                                  )
                                  .firstOrNull
                                  ?.route ??
                              section?.items
                                  .where(
                                    (item) => item.matches(
                                      GoRouterState.of(context).uri,
                                    ),
                                  )
                                  .firstOrNull
                                  ?.route ??
                              currentPath,
                    onNavigate: (route) => context.go(route),
                    actions: [
                      ...?config.shellActions?.call(context),
                      if (config.shellActions == null && config.auth != null)
                        BeakLogoutButton(
                          adapter:
                              config.auth?.adapter ??
                              beakDependencies(context)<BeakSessionStore>(),
                        ),
                      if (config.navigation?.searchInHeader != true)
                        OiButton.icon(
                          icon: OiIcons.search,
                          label:
                              '${BeakLocalizations.of(context).search} (Ctrl-K)',
                          onTap: openCommandBar,
                        ),
                      if (config.notifications
                          case final BeakNotificationSource source)
                        BeakNotificationBell(source: source),
                      // Listens directly to the controller: go_router preserves the
                      // shell across navigations, so it would not otherwise see mode
                      // changes.
                      if (config.navigation?.showThemeToggle ?? true)
                        ValueListenableBuilder<OiThemeMode>(
                          valueListenable: themeController,
                          builder: (context, mode, _) => OiThemeToggle(
                            currentMode: mode,
                            onModeChange: (next) =>
                                themeController.value = next,
                          ),
                        ),
                    ],
                    navigation: section != null
                        ? [
                            for (final item in section.items.where(visible))
                              navItem(item),
                          ]
                        : [
                            for (final resource in config.navigationResources)
                              if (resource.isVisible)
                                OiNavItem(
                                  label: resource.effectiveNavigationTitle,
                                  icon: resource.icon.icon,
                                  route: resource.route,
                                  section: resource.navigationGroup,
                                ),
                            for (final screen in config.pages)
                              if (screen.showInNav)
                                OiNavItem(
                                  label: screen.effectiveNavigationTitle,
                                  icon: screen.icon.icon,
                                  route: screen.path,
                                  section: screen.navigationGroup,
                                ),
                          ],
                    child: BeakPendingActions(
                      runner: beakDependencies(
                        context,
                      )<BeakModelActionRunner>(),
                      principal: switch ((config.auth?.adapter ??
                              (beakDependencies(
                                    context,
                                  ).isRegistered<BeakSessionStore>()
                                  ? beakDependencies(
                                      context,
                                    )<BeakSessionStore>()
                                  : null))
                          ?.state
                          .value) {
                        BeakAuthAuthenticated(:final identity) => identity.id,
                        _ => null,
                      },
                      child: BeakShellPageScope(
                        ownsBreadcrumbs: ownsBreadcrumbs,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    return switch (config.auth?.idleLockTimeout) {
      final Duration timeout => _BeakIdleLock(timeout: timeout, child: shell),
      null => shell,
    };
  }
}

/// Locks the panel to `/lock` after [timeout] of no pointer activity inside
/// the shell. Any pointer event resets the countdown; the timer is torn down
/// when the shell unmounts (e.g. once navigation reaches the lock screen), so
/// it never fires in a loop.
class _BeakIdleLock extends HookWidget {
  const _BeakIdleLock({required this.timeout, required this.child});

  final Duration timeout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final reset = useRef<VoidCallback>(() {});

    useEffect(() {
      Timer? timer;
      void schedule() {
        timer?.cancel();
        timer = Timer(timeout, () => router.go('/lock'));
      }

      // Keyboard events travel the focus pipeline, not the pointer pipeline
      // — without this hook, typing continuously in a form still locks the
      // panel mid-keystroke and destroys the unsaved input.
      bool onKey(KeyEvent event) {
        schedule();
        return false;
      }

      reset.value = schedule;
      schedule();
      HardwareKeyboard.instance.addHandler(onKey);
      return () {
        HardwareKeyboard.instance.removeHandler(onKey);
        timer?.cancel();
      };
    }, [timeout, router]);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => reset.value(),
      onPointerMove: (_) => reset.value(),
      onPointerSignal: (_) => reset.value(),
      child: child,
    );
  }
}

bool _fullScreenRoute(BeakPanelConfig config, String path) {
  for (final resource in config.resources) {
    if (!path.startsWith('${resource.route}/')) continue;
    final role = path == '${resource.route}/create'
        ? BeakScreenRole.create
        : path.endsWith('/edit')
        ? BeakScreenRole.edit
        : BeakScreenRole.read;
    final screen = resource.screenFor(role);
    return screen is BeakFormScreen && screen.fullScreen;
  }
  return false;
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.sections,
    required this.current,
    required this.visible,
  });
  final List<BeakNavigationSection> sections;
  final BeakNavigationSection? current;
  final bool Function(BeakNavigationItem) visible;
  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        sections.length *
            ((context.components.navigationRail?.itemHeight ?? 32) +
                (context.components.navigationRail?.itemSpacing ?? 4)) +
        8,
    child: OiNavigationRail(
      items: [
        for (final section in sections)
          OiNavigationItem(
            icon: section.icon,
            label: section.label,
            tooltip: section.label,
          ),
      ],
      currentIndex: sections.indexWhere(
        (section) => section.key == current?.key,
      ),
      onTap: (index) =>
          context.go(sections[index].items.firstWhere(visible).route),
      width: context.components.appShell?.primaryNavigationWidth ?? 64,
      labelBehavior: OiRailLabelBehavior.none,
      semanticLabel: 'Workspace settings',
    ),
  );
}
