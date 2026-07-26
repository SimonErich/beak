import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_superdashboard/server/server_builder.dart';
import 'package:worm/worm.dart';

/// Boots the superdashboard backend: loads `.env`, connects worm to Postgres,
/// resolves the configured storage driver, and serves the generated API for
/// every registered model.
Future<void> main() async {
  // The demo defaults to :8180 (the panel's apiBaseUrl); 8080-8082 are commonly
  // taken. A .env or real environment PORT still wins.
  final Map<String, String> environment = {
    'PORT': '8180',
    ...BeakEnv.resolve(),
  };
  final config = BeakBackendConfig.fromEnv(environment: environment);
  await initializeWormPostgres(config);
  final storageConfig = demoStorageConfig(environment);
  final server = buildDemoServer(
    config: config,
    adapter: Worm.adapter(),
    storage: storageConfig == null
        ? null
        : resolveStorage(storageConfig, registry: demoStorageRegistry()),
  );
  final HttpServer httpServer = await server.start();
  stderr.writeln(
    'beak_superdashboard listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
}
