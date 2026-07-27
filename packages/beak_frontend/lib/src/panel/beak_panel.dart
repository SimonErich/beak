import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:obers_ui/obers_ui.dart';

import '../di/beak_locator.dart';
import 'beak_panel_config.dart';
import 'beak_router.dart';
import 'beak_theme_controller.dart';

/// The Beak admin panel: give it a [BeakPanelConfig] and it stands up the
/// whole app — obers_ui theming, a go_router over every resource, the
/// generated shell navigation, and the data layer in GetIt.
///
/// This is the root widget of a Beak app; hand it to `runApp`. On first
/// build it registers the panel's dependencies (see
/// [registerBeakDependencies]) and builds the router, both memoized on
/// [config].
///
/// ```dart
/// void main() => runApp(
///   BeakPanel(config: buildPanelConfig()),
/// );
///
/// // In a widget test, inject a fake source so no HTTP is issued:
/// await tester.pumpWidget(
///   BeakPanel(config: buildPanelConfig(), dataSource: fakeSource),
/// );
/// ```
class BeakPanel extends HookWidget {
  /// Creates the panel for [config].
  ///
  /// [dataSource] and [httpClient] inject fakes in tests; production
  /// panels leave both null and talk HTTP to `config.apiBaseUrl`.
  const BeakPanel({
    required this.config,
    this.dataSource,
    this.httpClient,
    super.key,
  });

  /// The panel configuration.
  final BeakPanelConfig config;

  /// Test seam: replaces the HTTP-backed data source entirely.
  final BeakDataSource? dataSource;

  /// Test seam: replaces the HTTP transport under the typed client.
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = useMemoized(() {
      registerBeakDependencies(
        config: config,
        dataSource: dataSource,
        httpClient: httpClient,
      );
      return createBeakRouter(config);
      // The seams are part of the key: swapping a fake on rebuild used to
      // keep the previous one registered, so a test could not change source
      // mid-flight and never learned it had not.
    }, [config, dataSource, httpClient]);
    useEffect(() => router.dispose, [router]);
    final themeController = beakLocator<BeakThemeController>();
    return ValueListenableBuilder<OiThemeMode>(
      valueListenable: themeController,
      builder: (context, themeMode, _) => OiApp.router(
        routerConfig: router,
        title: config.title,
        theme: config.theme ?? OiThemeData.light(),
        darkTheme: config.darkTheme ?? OiThemeData.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
