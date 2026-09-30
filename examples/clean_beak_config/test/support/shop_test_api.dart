import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:clean_beak_config/beak/server.g.dart';

// --8<-- [start:ShopTestApi]
/// Real transactional example API for form-to-server integration tests.
final class ShopTestApi {
  ShopTestApi._(this.adapter, this.server, this.client);

  /// Isolated, in-memory SQLite database.
  final DatabaseAdapter adapter;

  /// HTTP server on an ephemeral loopback port.
  final HttpServer server;

  /// The same wire client used by the panel.
  final BeakClient client;

  /// Migrates and seeds a fresh database without touching the example's file.
  static Future<ShopTestApi> start() async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    final adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    final server = await host.buildServer(adapter: adapter).start();
    return ShopTestApi._(
      adapter,
      server,
      BeakClient(baseUrl: 'http://127.0.0.1:$port'),
    );
  }

  /// Releases all transport and database state after the test.
  Future<void> dispose() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  }
}
// --8<-- [end:ShopTestApi]
