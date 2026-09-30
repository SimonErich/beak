import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../auth/beak_auth_adapter.dart';
import '../auth/beak_session_store.dart';
import '../actions/beak_model_action_runner.dart';
import '../data/http_beak_data_source.dart';
import '../data/model_beak_data_source.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_theme_controller.dart';

/// The panel's dependency container — package-scoped so Beak never
/// collides with an app's own `GetIt.instance` registrations.
///
/// [registerBeakDependencies] populates it and the generated pages resolve
/// their dependencies from it, e.g. `beakLocator<BeakDataSource>()`.
final GetIt beakLocator = GetIt.asNewInstance();

// --8<-- [start:beakDependencies]
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
// --8<-- [end:beakDependencies]

/// Registers Beak's infrastructure for [config] into [locator] (defaults to
/// [beakLocator]): the [BeakModelRegistry], the [BeakClient] and the
/// [BeakDataSource].
///
/// [dataSource] replaces the HTTP-backed source: with the host's own transport
/// (the Serverpod admin) or with a fake in a test; [httpClient] swaps only the
/// transport under the real client;
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
///   dataSource: fakeSource, // omit to talk HTTP to the API origin
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
  BeakAuthAdapter? authority = config.auth?.adapter;
  if (externalAuthentication || authority != null) {
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
    // --8<-- [start:clientAndSessions]
    late final BeakSessionStore sessions;
    final client = BeakClient(
      baseUrl: config.apiBaseUrl,
      httpClient: httpClient,
      tokenProvider: tokenProvider ?? () => sessions.token,
    );
    sessions = BeakSessionStore(client);
    authority = sessions;
    fallback = dataSource ?? HttpBeakDataSource(client);
    container
      ..registerSingleton<BeakClient>(client)
      ..registerSingleton<BeakSessionStore>(sessions);
    // --8<-- [end:clientAndSessions]
  }
  // --8<-- [start:registerDataLayer]
  final source = ModelBeakDataSource(
    registry: registry,
    fallback: fallback,
    overrideBindings: dataSource != null,
    mapException: config.mapException,
    onUnauthorized: authority == null ? null : _endSessionOf(authority),
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
    ..registerSingleton<BeakThemeController>(
      BeakThemeController(config.initialThemeMode),
    );
  // --8<-- [end:registerDataLayer]
}

/// The hook that ends [authority]'s session when the server stops accepting it.
///
/// Requests that fail together end the session once, and a signed-out
/// authority is left alone.
void Function() _endSessionOf(BeakAuthAdapter authority) {
  var ending = false;
  return () {
    if (ending || authority.state.value is! BeakAuthAuthenticated) return;
    ending = true;
    unawaited(authority.logout().whenComplete(() => ending = false));
  };
}
