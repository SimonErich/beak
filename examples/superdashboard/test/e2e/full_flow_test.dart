@Tags(['e2e'])
library;

import 'dart:io';

import 'package:beak/panel.dart';
import 'package:superdashboard/seeders/demo_database_seeder.dart';
import 'package:superdashboard/beak/server.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beak/migrations.dart';

/// The connection base, taken from `DATABASE_URL` (compose default) so the
/// host/port/credentials stay overridable.
final Uri _databaseBase = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

/// The dedicated E2E database: the base database name with an `_e2e` suffix.
/// Derived — never taken verbatim from the environment — so an exported
/// `DATABASE_URL` pointing at the demo `beak` database can vary the connection
/// but can **never** aim the suite's fresh-migrate at real demo data.
String get _e2eDatabaseName {
  final String db = _databaseBase.pathSegments.isEmpty
      ? 'beak'
      : _databaseBase.pathSegments.first;
  return db.endsWith('_e2e') ? db : '${db}_e2e';
}

Uri get _e2eDatabaseUrl =>
    _databaseBase.replace(pathSegments: [_e2eDatabaseName]);

/// The suite always targets a dedicated `<db>_e2e` database with in-memory
/// storage — both forced *after* the environment spread — so its
/// fresh-migrate can never wipe the seeded demo data (`beak`) nor write to a
/// real object store, even when `DATABASE_URL` / `BEAK_STORAGE_DRIVER` are
/// exported (this repo's `.env` ships `DATABASE_URL` pointing at `beak`).
final Map<String, String> e2eEnvironment = {
  ...Platform.environment,
  'DATABASE_URL': _e2eDatabaseUrl.toString(),
  'BEAK_STORAGE_DRIVER': 'memory',
};

/// Creates [databaseUrl]'s database when it does not exist yet, via a
/// maintenance connection to the always-present `postgres` database.
/// `CREATE DATABASE` has no `IF NOT EXISTS`, so probe first.
Future<void> _ensureDatabase(Uri databaseUrl) async {
  final String name = databaseUrl.pathSegments.first;
  final maintenance = postgresAdapterFromUrl(
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

    // Defense in depth: never run the destructive reset against anything but a
    // dedicated *_e2e database, whatever the environment resolved to.
    final String dbName = databaseUrl.pathSegments.first;
    if (!dbName.endsWith('_e2e')) {
      throw StateError(
        'Refusing to reset non-e2e database "$dbName": the E2E suite only ever '
        'drops a *_e2e database.',
      );
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
      migrations: beakHost().migrations.toList(),
      seeders: const [DemoDatabaseSeeder()],
    ).fresh(seed: true);

    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final int port = probe.port;
    await probe.close();

    final server = beakHost(
      environment: {...e2eEnvironment, 'PORT': '$port', 'HOST': '127.0.0.1'},
    ).buildServer(adapter: connected);
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
