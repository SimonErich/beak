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
import 'beak_screen.dart';
import 'beak_navigation.dart';

/// The Beak admin panel: give it resources (or a full [BeakPanelConfig]) and
/// it stands up the whole app — obers_ui theming, a go_router over every
/// resource, the generated shell navigation, and the data layer in GetIt.
///
/// This is the root widget of a Beak app; hand it to `runApp`. On first
/// build it registers the panel's dependencies (see
/// [registerBeakDependencies]) and builds the router, both memoized on
/// [config].
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
/// // In a widget test, inject a fake source so no HTTP is issued:
/// await tester.pumpWidget(
///   BeakPanel(config: buildPanelConfig(), dataSource: fakeSource),
/// );
/// ```
class BeakPanel extends HookWidget {
  /// Creates the panel from either [config] or the individual arguments, never
  /// both. `resources:` is the everyday form; `config:` takes a complete
  /// [BeakPanelConfig] built by the host, including embedding options.
  ///
  /// [dataSource] and [httpClient] inject fakes in tests; production
  /// panels leave both null and talk HTTP to `apiBaseUrl`.
  const BeakPanel({
    BeakPanelConfig? config,
    List<BeakResource>? resources,
    this.title = 'Beak',
    this.theme,
    this.darkTheme,
    this.apiBaseUrl = const String.fromEnvironment(
      'BEAK_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    this.pages = const [],
    this.auth,
    this.locale,
    this.formatting,
    this.navigation,
    this.refreshPolicy,
    this.home,
    this.dataSource,
    this.httpClient,
    super.key,
  }) : assert(config == null || resources == null),
       _config = config,
       resources = resources ?? const [];

  final BeakPanelConfig? _config;

  /// Resources exposed by a directly configured panel.
  final List<BeakResource> resources;

  /// Application title.
  final String title;

  /// Light theme.
  final OiThemeData? theme;

  /// Dark theme.
  final OiThemeData? darkTheme;

  /// Backend origin, configurable through BEAK_API_BASE_URL.
  final String apiBaseUrl;

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

  /// The panel configuration.
  BeakPanelConfig get config =>
      _config ??
      BeakPanelConfig(
        title: title,
        resources: resources,
        theme: theme,
        darkTheme: darkTheme,
        apiBaseUrl: apiBaseUrl,
        pages: pages,
        auth: auth,
        locale: locale,
        formatting: formatting,
        navigation: navigation,
        refreshPolicy: refreshPolicy,
        home: home,
      );

  /// Test seam: replaces the HTTP-backed data source entirely.
  final BeakDataSource? dataSource;

  /// Test seam: replaces the HTTP transport under the typed client.
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
    ]);
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
