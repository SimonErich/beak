import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:showcase/beak/server.g.dart';

/// The real Aviary API over an isolated in-memory SQLite database.
///
/// Migrates and seeds a fresh database, serves it on an ephemeral loopback
/// port and hands out the same wire client the panel uses.
final class AviaryTestApi {
  AviaryTestApi._(this.adapter, this.server, this.client);

  /// The isolated database.
  final DatabaseAdapter adapter;

  /// The HTTP server on an ephemeral loopback port.
  final HttpServer server;

  /// The wire client the panel uses.
  final BeakClient client;

  /// Starts a fresh, migrated and seeded API.
  static Future<AviaryTestApi> start() async {
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
    return AviaryTestApi._(
      adapter,
      server,
      BeakClient(baseUrl: 'http://127.0.0.1:$port'),
    );
  }

  /// Releases every transport and database resource after the test.
  Future<void> dispose() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  }
}
