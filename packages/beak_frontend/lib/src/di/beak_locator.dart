import 'package:beak_core/beak_core.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../data/beak_client.dart';
import '../data/http_beak_data_source.dart';
import '../data/reference_cache.dart';
import '../panel/beak_panel_config.dart';

/// The panel's dependency container — package-scoped so Beak never
/// collides with an app's own `GetIt.instance` registrations.
final GetIt beakLocator = GetIt.asNewInstance();

/// Registers Beak's infrastructure for [config] in [locator]: the model
/// registry, the typed client, the data source (overridable with a fake
/// via [dataSource]), and the reference cache.
///
/// Existing registrations are reset first, so tests and hot restarts can
/// call this repeatedly.
Future<void> registerBeakDependencies({
  required BeakPanelConfig config,
  GetIt? locator,
  BeakDataSource? dataSource,
  http.Client? httpClient,
  String? Function()? tokenProvider,
}) async {
  final container = locator ?? beakLocator;
  await container.reset();
  final registry = config.buildRegistry();
  final client = BeakClient(
    baseUrl: config.apiBaseUrl,
    httpClient: httpClient,
    tokenProvider: tokenProvider,
  );
  final source = dataSource ?? HttpBeakDataSource(client);
  container
    ..registerSingleton<BeakPanelConfig>(config)
    ..registerSingleton<BeakModelRegistry>(registry)
    ..registerSingleton<BeakClient>(client)
    ..registerSingleton<BeakDataSource>(source)
    ..registerSingleton<ReferenceCache>(ReferenceCache(source, registry));
}
