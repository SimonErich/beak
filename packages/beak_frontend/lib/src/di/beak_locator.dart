import 'package:beak_core/beak_core.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../auth/beak_session_store.dart';
import '../actions/beak_model_action_runner.dart';
import '../data/http_beak_data_source.dart';
import '../data/model_beak_data_source.dart';
import '../data/reference_cache.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_theme_controller.dart';

/// The panel's dependency container — package-scoped so Beak never
/// collides with an app's own `GetIt.instance` registrations.
///
/// [registerBeakDependencies] populates it and the generated pages resolve
/// their dependencies from it, e.g. `beakLocator<BeakDataSource>()`.
final GetIt beakLocator = GetIt.asNewInstance();

/// The nearest panel's dependencies, falling back to the explicit host setup.
GetIt beakDependencies(BuildContext context) =>
    context
        .dependOnInheritedWidgetOfExactType<BeakDependencyScope>()
        ?.container ??
    beakLocator;

/// Keeps transports, references and authentication local to one panel tree.
class BeakDependencyScope extends InheritedWidget {
  /// Exposes [container] to the widgets below this scope.
  const BeakDependencyScope({
    required this.container,
    required super.child,
    super.key,
  });

  /// The dependency container owned by this panel.
  final GetIt container;

  @override
  bool updateShouldNotify(BeakDependencyScope oldWidget) =>
      container != oldWidget.container;
}

/// Registers Beak's infrastructure for [config] into [locator] (defaults to
/// [beakLocator]): the [BeakModelRegistry], the [BeakClient], the
/// [BeakDataSource], and the [ReferenceCache].
///
/// [dataSource] overrides the HTTP-backed source with a fake for tests;
/// [httpClient] swaps only the transport under the real client;
/// [tokenProvider] supplies the bearer token per request — omit it and the
/// registered [BeakSessionStore] supplies it, so signing in is all it takes. Registration is
/// synchronous — the router built right after reads the locator on its
/// first frame — and re-registration replaces the previous panel's entries,
/// so tests and hot restarts can call it repeatedly.
///
/// [BeakPanel] calls this for you; call it directly only when driving the
/// router without the panel widget:
///
/// ```dart
/// registerBeakDependencies(
///   config: buildPanelConfig(),
///   dataSource: fakeSource, // omit in production to talk HTTP
/// );
/// final source = beakLocator<BeakDataSource>();
/// ```
void registerBeakDependencies({
  required BeakPanelConfig config,
  GetIt? locator,
  BeakDataSource? dataSource,
  http.Client? httpClient,
  String? Function()? tokenProvider,
  bool externalAuthentication = false,
}) {
  final container = locator ?? beakLocator;
  container.allowReassignment = true;
  final registry = config.buildRegistry();
  // The store is created before the client so the client can read its token,
  // and given the client afterwards so it can mint one — the two halves of
  // one session.
  BeakDataSource? fallback;
  if (externalAuthentication || config.auth?.adapter != null) {
    if (dataSource == null &&
        registry.all.any((model) => model.dataSource == null)) {
      throw const BeakConfigurationException(
        'External authentication requires bound models or a data source.',
      );
    }
    fallback = dataSource;
    if (container.isRegistered<BeakClient>()) {
      container.unregister<BeakClient>();
    }
    if (container.isRegistered<BeakSessionStore>()) {
      container.unregister<BeakSessionStore>();
    }
  } else {
    late final BeakSessionStore sessions;
    final client = BeakClient(
      baseUrl: config.apiBaseUrl,
      httpClient: httpClient,
      tokenProvider: tokenProvider ?? () => sessions.token,
    );
    sessions = BeakSessionStore(client);
    fallback = dataSource ?? HttpBeakDataSource(client);
    container
      ..registerSingleton<BeakClient>(client)
      ..registerSingleton<BeakSessionStore>(sessions);
  }
  final source = ModelBeakDataSource(
    registry: registry,
    fallback: fallback,
    overrideBindings: dataSource != null,
    mapException: config.mapException,
    refreshPolicy: config.refreshPolicy,
  );
  container
    ..registerSingleton<BeakModelActionRunner>(
      BeakModelActionRunner(),
      dispose: (runner) => runner.dispose(),
    )
    ..registerSingleton<BeakPanelConfig>(config)
    ..registerSingleton<BeakModelRegistry>(registry)
    ..registerSingleton<BeakDataSource>(
      source,
      dispose: (_) => source.dispose(),
    )
    ..registerSingleton<ReferenceCache>(
      ReferenceCache(
        source,
        registry,
        auth:
            config.auth?.adapter ??
            (container.isRegistered<BeakSessionStore>()
                ? container<BeakSessionStore>()
                : null),
      ),
      dispose: (cache) => cache.dispose(),
    )
    ..registerSingleton<BeakThemeController>(
      BeakThemeController(config.initialThemeMode),
    );
}
