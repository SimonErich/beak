@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:beak/migrations.dart';
import 'package:test/test.dart';

import '../api_scenario.dart';

/// The same API scenario against Postgres from `docker-compose.yml`.
///
/// Tagged `e2e` because the identical assertions already run on SQLite on
/// every pull request. What this adds is the half a driver can differ on —
/// real `uuid` columns, real `ilike`, real transactions — which is worth a
/// slower, opt-in run. Uploads stay on local disk here; `examples/embedded`
/// is where the S3 driver is exercised.
///
/// Start the services with `melos run up`, then: `dart test --tags e2e`.
void main() {
  final Uri base = Uri.parse(
    Platform.environment['DATABASE_URL'] ??
        'postgres://beak:beak@localhost:25432/beak',
  );

  // Derived, never taken verbatim: an exported DATABASE_URL may vary the
  // host and credentials, but this suite's fresh-migrate only ever lands in a
  // database whose name ends in `_store_e2e`.
  final String database = switch (base.pathSegments) {
    [final String name, ...] when name.endsWith('_store_e2e') => name,
    [final String name, ...] => '${name}_store_e2e',
    _ => 'beak_store_e2e',
  };
  final Uri databaseUrl = base.replace(pathSegments: [database]);
  final Directory uploads = Directory.systemTemp.createTempSync(
    'store_e2e_uploads_',
  );
  tearDownAll(() => uploads.deleteSync(recursive: true));

  setUpAll(() async {
    if (!await _reachable(databaseUrl)) {
      throw StateError(
        'Postgres is unreachable — start it with `melos run up`.',
      );
    }
    await _ensureDatabase(databaseUrl);
    await _dropDomainTables(databaseUrl);
  });

  runStoreApiScenario(
    description: 'store API on postgres',
    environmentFor: (port) => {
      'DATABASE_URL': databaseUrl.toString(),
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
}

/// Whether something is listening at [url].
Future<bool> _reachable(Uri url) async {
  try {
    final socket = await Socket.connect(
      url.host,
      url.port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

/// Creates [databaseUrl]'s database when it does not exist yet.
///
/// `CREATE DATABASE` has no `IF NOT EXISTS`, so probe first — through the
/// always-present `postgres` database.
Future<void> _ensureDatabase(Uri databaseUrl) async {
  final String name = databaseUrl.pathSegments.first;
  final maintenance = adapterFromUrl(
    databaseUrl.replace(pathSegments: const ['postgres']),
  );
  await maintenance.connect();
  try {
    final rows = await maintenance.rawQuery(
      r'SELECT 1 FROM pg_database WHERE datname = $1',
      [name],
    );
    if (rows.isEmpty) {
      await maintenance.rawQuery('CREATE DATABASE "$name"', const []);
    }
  } finally {
    await maintenance.disconnect();
  }
}

/// Drops the store's tables so a run left half-finished cannot fail the next
/// one's fresh migrate.
///
/// Safe because the database name is derived, not taken from the
/// environment: this only ever runs against `*_store_e2e`.
Future<void> _dropDomainTables(Uri databaseUrl) async {
  const tables = [
    'order_items',
    'orders',
    'product_tag',
    'roast_profiles',
    'products',
    'users',
    'tags',
    'categories',
    'migrations',
  ];
  final adapter = adapterFromUrl(databaseUrl);
  await adapter.connect();
  try {
    for (final table in tables) {
      await adapter.rawQuery('DROP TABLE IF EXISTS "$table" CASCADE', const []);
    }
  } finally {
    await adapter.disconnect();
  }
}
