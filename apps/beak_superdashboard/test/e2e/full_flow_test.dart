@Tags(['e2e'])
library;

import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/migrations/demo_migrations.dart';
import 'package:beak_superdashboard/seeders/demo_database_seeder.dart';
import 'package:beak_superdashboard/server/server_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worm/worm.dart';

/// Docker-compose defaults, overridable via the environment.
///
/// The suite targets a dedicated `beak_e2e` database (created on demand), so
/// its fresh-migrate never wipes the seeded demo data in the default `beak`
/// database.
final Map<String, String> e2eEnvironment = {
  'DATABASE_URL': 'postgres://beak:beak@localhost:25432/beak_e2e',
  'BEAK_STORAGE_DRIVER': 'memory',
  ...Platform.environment,
};

/// Creates [databaseUrl]'s database when it does not exist yet, via a
/// maintenance connection to the compose stack's always-present `beak`
/// database. `CREATE DATABASE` has no `IF NOT EXISTS`, so probe first.
Future<void> _ensureDatabase(Uri databaseUrl) async {
  final String name = databaseUrl.pathSegments.first;
  final maintenance = postgresAdapterFromUrl(databaseUrl.replace(path: 'beak'));
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

Future<bool> _reachable(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  final Uri databaseUrl = Uri.parse(e2eEnvironment['DATABASE_URL'] ?? '');

  late bool servicesUp;
  DatabaseAdapter? adapter;
  HttpServer? httpServer;
  late BeakDataSource source;

  setUpAll(() async {
    servicesUp = await _reachable(databaseUrl.host, databaseUrl.port);
    if (!servicesUp) {
      return;
    }

    await _ensureDatabase(databaseUrl);
    final connected = postgresAdapterFromUrl(databaseUrl);
    await connected.connect();
    adapter = connected;

    // Start from a pristine schema so a dirty database never blocks the run.
    await connected.rawQuery('DROP SCHEMA public CASCADE', const []);
    await connected.rawQuery('CREATE SCHEMA public', const []);

    await MigrationRunner(
      adapter: connected,
      migrations: demoMigrations.toList(),
      seeders: const [DemoDatabaseSeeder()],
    ).fresh(seed: true);

    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final int port = probe.port;
    await probe.close();

    final server = buildDemoServer(
      config: BeakBackendConfig.fromEnv(
        environment: {...e2eEnvironment, 'PORT': '$port', 'HOST': '127.0.0.1'},
      ),
      adapter: connected,
    );
    httpServer = await server.start();
    source = HttpBeakDataSource(BeakClient(baseUrl: 'http://127.0.0.1:$port'));
  });

  tearDownAll(() async {
    if (httpServer case final HttpServer running) {
      await running.close(force: true);
    }
    if (adapter case final DatabaseAdapter connected) {
      await connected.disconnect();
    }
  });

  bool guarded() {
    if (!servicesUp) {
      markTestSkipped('Postgres unreachable — start it with `melos run up`.');
    }
    return servicesUp;
  }

  test(
    'migrate + seed builds the whole schema and serves paged users',
    () async {
      if (!guarded()) {
        return;
      }
      final page = await source.query(
        const BeakQuerySpec(
          table: 'users',
          pagination: BeakPagination(perPage: 10),
        ),
      );
      expect(page.total, 40);
      expect(page.items, hasLength(10));
    },
  );

  test('aggregates the seeded order count over HTTP', () async {
    if (!guarded()) {
      return;
    }
    final count = await source.aggregate(
      const BeakAggregateSpec.count(table: 'orders'),
    );
    expect(count, 100);
  });

  test('eager-loads belongs-to and has-many relations', () async {
    if (!guarded()) {
      return;
    }
    final page = await source.query(
      const BeakQuerySpec(
        table: 'orders',
        pagination: BeakPagination(perPage: 5),
        relationLoads: [BeakRelationLoad('user'), BeakRelationLoad('items')],
      ),
    );
    expect(page.items, isNotEmpty);
    final withUser = page.items.where(
      (order) => (order.relations['user'] ?? const []).isNotEmpty,
    );
    expect(withUser, isNotEmpty, reason: 'orders should load their customer');
    final withItems = page.items.where(
      (order) => (order.relations['items'] ?? const []).isNotEmpty,
    );
    expect(withItems, isNotEmpty, reason: 'orders should load line items');
  });

  test('eager-loads a self-referential folder tree on real Postgres', () async {
    if (!guarded()) {
      return;
    }
    final page = await source.query(
      const BeakQuerySpec(
        table: 'file_folders',
        pagination: BeakPagination(perPage: 100),
        relationLoads: [BeakRelationLoad('children')],
      ),
    );
    final roots = page.items.where(
      (folder) => folder['parent_id']?.raw == null,
    );
    final rootsWithChildren = roots.where(
      (folder) => (folder.relations['children'] ?? const []).isNotEmpty,
    );
    expect(
      rootsWithChildren,
      isNotEmpty,
      reason: 'root folders should load their sub-folders',
    );
  });

  test('purchase-source revenue reconciles with orders over HTTP', () async {
    if (!guarded()) {
      return;
    }
    final orders = await source.query(
      const BeakQuerySpec(
        table: 'orders',
        pagination: BeakPagination(perPage: 500),
      ),
    );
    final sources = await source.query(
      const BeakQuerySpec(
        table: 'purchase_sources',
        pagination: BeakPagination(perPage: 50),
      ),
    );
    // Postgres decimals arrive as JSON strings; parse either shape.
    double asDouble(Object? raw) => switch (raw) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value) ?? 0,
      _ => 0,
    };
    double total(Iterable<BeakRecord> rows, String key) =>
        rows.fold(0, (sum, row) => sum + asDouble(row[key]?.raw));
    expect(
      total(sources.items, 'total'),
      closeTo(total(orders.items, 'total'), 1.0),
    );
  });

  test('round-trips a category through create/update/delete', () async {
    if (!guarded()) {
      return;
    }
    final created = await source.create(
      'categories',
      BeakRecord.fromRow(const {'name': 'E2E Temp'}),
    );
    final Object id = created['id']!.raw!;
    expect(created['name'], const BeakStringValue('E2E Temp'));

    final updated = await source.update(
      'categories',
      id,
      BeakRecord.fromRow(const {'name': 'E2E Renamed'}),
    );
    expect(updated['name'], const BeakStringValue('E2E Renamed'));

    await source.delete('categories', id);
    expect(await source.getOne('categories', id), isNull);
  });
}
