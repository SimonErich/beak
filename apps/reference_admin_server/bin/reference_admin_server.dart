import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:reference_admin_server/reference_admin_server.dart';
import 'package:worm/worm.dart';

/// Boots the reference Beak backend: loads `.env`, connects worm to
/// Postgres, resolves the configured storage driver, and serves the
/// generated API for every shared model.
Future<void> main() async {
  final Map<String, String> environment = BeakEnv.resolve();
  final config = BeakBackendConfig.fromEnv(environment: environment);
  await initializeWormPostgres(config);
  final storageConfig = referenceStorageConfig(environment);
  final server = buildReferenceServer(
    config: config,
    adapter: Worm.adapter(),
    storage: storageConfig == null
        ? null
        : resolveStorage(storageConfig, registry: referenceStorageRegistry()),
  );
  final HttpServer httpServer = await server.start();
  stderr.writeln(
    'reference_admin_server listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
}
