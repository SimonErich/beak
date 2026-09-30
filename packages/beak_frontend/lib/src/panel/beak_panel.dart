import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:obers_ui/obers_ui.dart';

import '../di/beak_locator.dart';
import '../data/beak_data_changes.dart';
import '../data/model_beak_data_source.dart';
import '../auth/beak_auth_gate.dart';
import '../auth/beak_session_store.dart';
import '../localization/beak_localizations.dart';
import '../formatting/beak_formatting.dart';
import 'beak_panel_config.dart';
import 'beak_router.dart';
import 'beak_theme_controller.dart';
import 'beak_auth_config.dart';
import 'beak_destination.dart';
import 'beak_maintenance_config.dart';
import 'beak_screen.dart';
import 'beak_navigation.dart';

/// The Beak admin panel: give it resources (or a full [BeakPanelConfig]) and
/// it stands up the whole app — obers_ui theming, a go_router over every
/// resource, the generated shell navigation, and the data layer in GetIt.
///
/// This is the root widget of a Beak app; hand it to `runApp`. On first
/// build it registers the panel's dependencies (see
/// [registerBeakDependencies]) and builds the router, both memoized on
/// [config] and the arguments it is built from. Those keys are identities: a
/// rebuild that passes new list or resource instances starts a new router and
/// a new session, so keep the configuration in a field or a `const`.
///
/// ```dart
/// void main() => runApp(
///   BeakPanel(title: 'Shop', resources: [ProductResource()]),
/// );
///
/// // A complete, shared configuration goes through `config:`.
/// void mainFromConfig() => runApp(
///   BeakPanel(config: buildPanelConfig()),
/// );
///
/// // A test, or a host with its own transport, injects the data source:
/// await tester.pumpWidget(
///   BeakPanel(config: buildPanelConfig(), dataSource: fakeSource),
/// );
/// ```
class BeakPanel extends HookWidget {
  /// Creates the panel from either [config] or the individual arguments, never
  /// both. `resources:` is the everyday form; `config:` takes a complete
  /// [BeakPanelConfig] built by the host, including embedding options. Giving
  /// `config:` together with any of the individual arguments throws a
  /// [BeakConfigurationException] when the panel builds, because the
  /// configuration would silently win.
  ///
  /// [dataSource] and [httpClient] work with either form. A panel that leaves
  /// both null talks HTTP to its API origin; a host with its own transport
  /// (the Serverpod admin) supplies [dataSource], and a test supplies a fake.
  const BeakPanel({
    BeakPanelConfig? config,
    List<BeakResource>? resources,
    this.title,
    this.theme,
    this.darkTheme,
    this.apiBaseUrl,
    this.pages = const [],
    this.auth,
    this.locale,
    this.formatting,
    this.navigation,
    this.refreshPolicy,
    this.home,
    this.maintenance,
    this.mapException,
    this.dataSource,
    this.httpClient,
    super.key,
  }) : assert(config == null || resources == null),
       _config = config,
       resources = resources ?? const [];

  final BeakPanelConfig? _config;

  /// Resources exposed by a directly configured panel.
  final List<BeakResource> resources;

  /// Application title; `Beak` when null.
  final String? title;

  /// Light theme.
  final OiThemeData? theme;

  /// Dark theme.
  final OiThemeData? darkTheme;

  /// Backend origin; the `BEAK_API_BASE_URL` compile-time variable, else
  /// `http://localhost:8080`, when null.
  final String? apiBaseUrl;

  /// Additional custom pages.
  final List<BeakScreen> pages;

  /// Optional authentication configuration.
  final BeakAuthConfig? auth;

  /// Application locale; null follows the platform.
  final Locale? locale;

  /// Shared date, number and currency display policy.
  final BeakFormatting? formatting;

  /// Shared periodic/foreground invalidation for asynchronous server effects.
  final BeakRefreshPolicy? refreshPolicy;

  /// Optional primary rail and contextual navigation.
  final BeakNavigation? navigation;

  /// Where `/` sends the user when no page claims it; see
  /// [BeakPanelConfig.home].
  final BeakDestination? home;

  /// The `/maintenance` and `/coming-soon` pages; see
  /// [BeakPanelConfig.maintenance].
  final BeakMaintenanceConfig? maintenance;

  /// Maps a host exception, such as a Serverpod protocol error, to a
  /// [BeakException]; see [BeakPanelConfig.mapException].
  final BeakException? Function(Exception exception, StackTrace stackTrace)?
  mapException;

  /// The panel configuration.
  ///
  /// Throws a [BeakConfigurationException] when [config] was given together
  /// with individual arguments the configuration would ignore.
  BeakPanelConfig get config {
    if (_config case final BeakPanelConfig given) {
      final ignored = _ignoredShorthand();
      if (ignored.isNotEmpty) {
        throw BeakConfigurationException(
          'BeakPanel was given a config and also ${ignored.join(', ')}, which '
          'the config would ignore. Set them on the BeakPanelConfig '
          '(copyWith) or drop the config.',
        );
      }
      return given;
    }
    return BeakPanelConfig(
      title: title ?? 'Beak',
      resources: resources,
      theme: theme,
      darkTheme: darkTheme,
      apiBaseUrl:
          apiBaseUrl ??
          const String.fromEnvironment(
            'BEAK_API_BASE_URL',
            defaultValue: 'http://localhost:8080',
          ),
      pages: pages,
      auth: auth,
      locale: locale,
      formatting: formatting,
      navigation: navigation,
      refreshPolicy: refreshPolicy,
      home: home,
      maintenance: maintenance,
      mapException: mapException,
    );
  }

  List<String> _ignoredShorthand() => [
    if (resources.isNotEmpty) 'resources',
    if (title != null) 'title',
    if (theme != null) 'theme',
    if (darkTheme != null) 'darkTheme',
    if (apiBaseUrl != null) 'apiBaseUrl',
    if (pages.isNotEmpty) 'pages',
    if (auth != null) 'auth',
    if (locale != null) 'locale',
    if (formatting != null) 'formatting',
    if (navigation != null) 'navigation',
    if (refreshPolicy != null) 'refreshPolicy',
    if (home != null) 'home',
    if (maintenance != null) 'maintenance',
    if (mapException != null) 'mapException',
  ];

  /// Replaces the HTTP-backed data source entirely: a fake in a test, or the
  /// host's own transport such as the Serverpod admin's.
  final BeakDataSource? dataSource;

  /// Replaces the HTTP transport under the typed client, for a test or a host
  /// that adds its own headers or retries.
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    final config = useMemoized(() => this.config, [
      _config,
      resources,
      title,
      theme,
      darkTheme,
      apiBaseUrl,
      pages,
      auth,
      locale,
      formatting,
      navigation,
      refreshPolicy,
      home,
      maintenance,
      mapException,
    ]);
    // --8<-- [start:panelRouting]
    final routing = useMemoized(() {
      final container = GetIt.asNewInstance();
      registerBeakDependencies(
        locator: container,
        config: config,
        dataSource: dataSource,
        httpClient: httpClient,
      );
      final authRefresh = config.auth == null
          ? null
          : BeakAuthRouterRefresh(
              config.auth?.adapter ?? container<BeakSessionStore>(),
            );
      return (
        container: container,
        router: createBeakRouter(config, authRefresh: authRefresh),
        authRefresh: authRefresh,
      );
      // The seams are part of the key: swapping a fake on rebuild used to
      // keep the previous one registered, so a test could not change source
      // mid-flight and never learned it had not.
    }, [config, dataSource, httpClient]);
    // --8<-- [end:panelRouting]
    final GoRouter router = routing.router;
    final source = routing.container<BeakDataSource>();
    final lifecycle = useAppLifecycleState();
    useEffect(() {
      if (source is ModelBeakDataSource) {
        source.setForeground(
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
        );
      }
      return null;
    }, [source, lifecycle]);
    useEffect(
      () => () {
        router.dispose();
        routing.authRefresh?.dispose();
        if (routing.container.isRegistered<BeakClient>()) {
          routing.container<BeakClient>().close();
        }
        routing.container<BeakThemeController>().dispose();
        routing.container.reset();
      },
      [routing],
    );
    final themeController = routing.container<BeakThemeController>();
    final panel = BeakDependencyScope(
      container: routing.container,
      child: ValueListenableBuilder<OiThemeMode>(
        valueListenable: themeController,
        builder: (context, themeMode, _) => OiApp.router(
          routerConfig: router,
          title: config.title,
          theme: config.theme ?? OiThemeData.light(),
          darkTheme: config.darkTheme ?? OiThemeData.dark(),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          locale: config.locale,
          supportedLocales: config.supportedLocales,
          localizationsDelegates: [
            ...config.localizationsDelegates,
            BeakLocalizations.delegate,
          ],
        ),
      ),
    );
    final effectiveFormatting = config.formatting;
    return effectiveFormatting == null
        ? panel
        : BeakFormattingScope(formatting: effectiveFormatting, child: panel);
  }
}
