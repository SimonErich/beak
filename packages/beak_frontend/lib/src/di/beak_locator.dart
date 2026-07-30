import 'package:beak_core/beak_core.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../auth/beak_session_store.dart';
import '../data/http_beak_data_source.dart';
import '../data/reference_cache.dart';
import '../panel/beak_panel_config.dart';
import '../panel/beak_theme_controller.dart';

/// The panel's dependency container — package-scoped so Beak never
/// collides with an app's own `GetIt.instance` registrations.
///
/// [registerBeakDependencies] populates it and the generated pages resolve
/// their dependencies from it, e.g. `beakLocator<BeakDataSource>()`.
final GetIt beakLocator = GetIt.asNewInstance();

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
}) {
  final container = locator ?? beakLocator;
  container.allowReassignment = true;
  final registry = config.buildRegistry();
  // The store is created before the client so the client can read its token,
  // and given the client afterwards so it can mint one — the two halves of
  // one session.
  late final BeakSessionStore sessions;
  final client = BeakClient(
    baseUrl: config.apiBaseUrl,
    httpClient: httpClient,
    tokenProvider: tokenProvider ?? () => sessions.token,
  );
  sessions = BeakSessionStore(client);
  final source = dataSource ?? HttpBeakDataSource(client);
  container
    ..registerSingleton<BeakPanelConfig>(config)
    ..registerSingleton<BeakModelRegistry>(registry)
    ..registerSingleton<BeakClient>(client)
    ..registerSingleton<BeakSessionStore>(sessions)
    ..registerSingleton<BeakDataSource>(source)
    ..registerSingleton<ReferenceCache>(ReferenceCache(source, registry))
    ..registerSingleton<BeakThemeController>(
      BeakThemeController(config.initialThemeMode),
    );
}
