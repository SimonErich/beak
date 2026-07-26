@Tags(['e2e'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:reference_admin_server/reference_admin_server.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// A real, decodable PNG — small enough for every rule, real enough for
/// the transform pipeline.
final Uint8List testPng = img.encodePng(img.Image(width: 8, height: 8));

/// The connection base, taken from `DATABASE_URL` (compose default) so the
/// host/port/credentials stay overridable.
final Uri _databaseBase = Uri.parse(
  Platform.environment['DATABASE_URL'] ??
      'postgres://beak:beak@localhost:25432/beak',
);

/// The dedicated E2E database: the base database name with a
/// `_reference_e2e` suffix. Derived — never taken verbatim from the
/// environment — so an exported `DATABASE_URL` pointing at the shared demo
/// `beak` database can vary the connection but can **never** aim this
/// suite's table drops and fresh-migrate at real demo data. The suffix also
/// differs from beak_superdashboard's `_e2e`, so the two suites cannot
/// clobber each other when the full gate runs them concurrently.
String get _e2eDatabaseName {
  final String db = _databaseBase.pathSegments.isEmpty
      ? 'beak'
      : _databaseBase.pathSegments.first;
  return db.endsWith('_reference_e2e') ? db : '${db}_reference_e2e';
}

Uri get _e2eDatabaseUrl =>
    _databaseBase.replace(pathSegments: [_e2eDatabaseName]);

/// Docker-compose defaults, overridable via the environment — except
/// `DATABASE_URL`, forced *after* the spread onto the dedicated
/// `_reference_e2e` database so no environment can redirect the suite's
/// destructive setup at shared data.
final Map<String, String> e2eEnvironment = {
  'BEAK_STORAGE_DRIVER': 's3',
  'BEAK_S3_ENDPOINT': 'http://localhost:29000',
  'BEAK_S3_BUCKET': 'beak-uploads',
  'BEAK_S3_ACCESS_KEY': 'beak',
  'BEAK_S3_SECRET_KEY': 'beaksecret',
  'BEAK_S3_REGION': 'us-east-1',
  'BEAK_S3_USE_PATH_STYLE': 'true',
  ...Platform.environment,
  'DATABASE_URL': _e2eDatabaseUrl.toString(),
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
  final Uri minioEndpoint = Uri.parse(e2eEnvironment['BEAK_S3_ENDPOINT'] ?? '');

  late bool servicesUp;
  DatabaseAdapter? adapter;
  HttpServer? httpServer;
  late BeakClient client;

  setUpAll(() async {
    servicesUp =
        await _reachable(databaseUrl.host, databaseUrl.port) &&
        await _reachable(minioEndpoint.host, minioEndpoint.port);
    if (!servicesUp) {
      return;
    }

    // Defense in depth: never run the destructive table drops and
    // fresh-migrate against anything but a dedicated *_e2e database,
    // whatever the environment resolved to.
    final String dbName = databaseUrl.pathSegments.first;
    if (!dbName.endsWith('_e2e')) {
      throw StateError(
        'Refusing to reset non-e2e database "$dbName": the E2E suite only '
        'ever drops tables in a *_e2e database.',
      );
    }
    await _ensureDatabase(databaseUrl);

    // The full gate runs every suite concurrently; under that load the
    // first pooled connection can miss its request timeout — retry it.
    late DatabaseAdapter connected;
    for (var attempt = 1; ; attempt++) {
      connected = postgresAdapterFromUrl(databaseUrl);
      await connected.connect();
      try {
        await connected.rawQuery('SELECT 1', const []);
        break;
      } on Object {
        await connected.disconnect();
        if (attempt >= 5) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    adapter = connected;

    // A dirty database from an earlier run must not fail schema creation.
    const domainTables = [
      'order_items',
      'orders',
      'product_tag',
      'products',
      'users',
      'tags',
      'categories',
    ];
    for (final table in domainTables) {
      await connected.rawQuery(
        'DROP TABLE IF EXISTS "$table" CASCADE',
        const [],
      );
    }
    final runner = MigrationRunner(
      adapter: connected,
      migrations: referenceMigrations.toList(),
      seeders: const [ReferenceSeeder()],
    );
    await runner.fresh(seed: true);

    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final int port = probe.port;
    await probe.close();

    final host = referenceHost(
      environment: {...e2eEnvironment, 'PORT': '$port', 'HOST': '127.0.0.1'},
    );
    final server = host.buildServer(
      adapter: connected,
      storage:
          host.resolveStorageDriver() ??
          (throw StateError('e2e requires a storage driver')),
    );
    httpServer = await server.start();
    client = BeakClient(baseUrl: 'http://127.0.0.1:$port');
  });

  tearDownAll(() async {
    if (httpServer case final HttpServer running) {
      client.close();
      await running.close(force: true);
    }
    if (adapter case final DatabaseAdapter connected) {
      await connected.disconnect();
    }
  });

  /// Skips the calling test with a clear message when the Docker services
  /// are down; the final gate runs with `melos run up` done, so the flow
  /// then runs for real.
  bool guarded() {
    if (!servicesUp) {
      markTestSkipped(
        'Postgres/MinIO unreachable — start them with `melos run up`.',
      );
      return false;
    }
    return true;
  }

  group('full flow', () {
    test(
      'queries products paged, sorted, searched, relations loaded',
      () async {
        if (!guarded()) {
          return;
        }
        final page = await client.query(
          'products',
          const BeakQuerySpec(
            table: 'products',
            sorts: [BeakSort('name')],
            relationLoads: [
              BeakRelationLoad('category'),
              BeakRelationLoad('tags'),
            ],
            pagination: BeakPagination(perPage: 2),
          ),
        );
        expect(page.total, 3);
        expect(page.items, hasLength(2));

        final searched = await client.query(
          'products',
          const BeakQuerySpec(
            table: 'products',
            search: BeakSearch('espresso', ['name', 'description']),
            relationLoads: [
              BeakRelationLoad('category'),
              BeakRelationLoad('tags'),
            ],
          ),
        );
        expect(searched.total, 1);
        final espresso = searched.items.single;
        expect(
          espresso.relations['category']?.single['name'],
          const BeakStringValue('Coffee'),
        );
        expect(espresso.relations['tags'], hasLength(2));
      },
    );

    test('creates with validation: valid → 201, invalid → typed 422', () async {
      if (!guarded()) {
        return;
      }
      final created = await client.create(
        'products',
        BeakRecord.fromRow(const {
          'name': 'V60 Dripper',
          'price': 24.0,
          'stock': 12,
          'status': 'published',
          'category_id': ReferenceSeedIds.categoryGear,
        }),
      );
      expect(created['id']?.raw, isNotNull);
      expect(created['created_at']?.raw, isNotNull);

      await expectLater(
        client.create('products', BeakRecord.fromRow(const {'price': -1})),
        throwsA(
          isA<BeakValidationException>().having(
            (exception) => exception.fieldErrors.keys,
            'fieldErrors',
            containsAll(['name', 'price']),
          ),
        ),
      );
    });

    test(
      'uploads a real PNG: stored in MinIO with a thumbnail variant',
      () async {
        if (!guarded()) {
          return;
        }
        final stored = await client.upload(
          'products',
          'image',
          BeakUpload(
            filename: 'red.png',
            mimeType: 'image/png',
            bytes: testPng,
          ),
        );

        expect(stored.key, startsWith('products/'));
        expect(stored.variants, contains('thumbnail'));

        final original = await http.get(stored.url);
        expect(original.statusCode, 200);
        expect(original.bodyBytes, isNotEmpty);

        final thumbnailUrl = stored.variants['thumbnail']?.url;
        expect(thumbnailUrl, isNotNull);
        if (thumbnailUrl != null) {
          final thumbnail = await http.get(thumbnailUrl);
          expect(thumbnail.statusCode, 200);
          expect(thumbnail.bodyBytes, isNotEmpty);
        }
      },
    );

    test('update, soft delete (hidden), then force delete (gone)', () async {
      if (!guarded()) {
        return;
      }
      final created = await client.create(
        'products',
        BeakRecord.fromRow(const {
          'name': 'Fleeting Filter',
          'price': 3.5,
          'status': 'draft',
        }),
      );
      final Object id = switch (created['id']?.raw) {
        final Object value => value,
        null => fail('created product has no id'),
      };

      final updated = await client.update(
        'products',
        id,
        BeakRecord.fromRow(const {'name': 'Fleeting Filter v2'}),
      );
      expect(updated['name'], const BeakStringValue('Fleeting Filter v2'));

      await client.delete('products', id);
      expect(await client.getOne('products', id), isNull);
      final trashed = await client.query(
        'products',
        const BeakQuerySpec(table: 'products', withTrashed: true),
      );
      expect(trashed.items.map((record) => record['id']?.raw), contains(id));

      await client.delete('products', id, force: true);
      final afterForce = await client.query(
        'products',
        const BeakQuerySpec(table: 'products', withTrashed: true),
      );
      expect(
        afterForce.items.map((record) => record['id']?.raw),
        isNot(contains(id)),
      );
    });

    test('attaches and detaches tags through the pivot', () async {
      if (!guarded()) {
        return;
      }
      await client.attach('products', ReferenceSeedIds.productGrinder, 'tags', [
        ReferenceSeedIds.tagNew,
      ]);
      final withNew = await client.query(
        'products',
        const BeakQuerySpec(
          table: 'products',
          filter: BeakFieldFilter.forKey(
            'id',
            BeakOperator.eq,
            BeakStringValue(ReferenceSeedIds.productGrinder),
          ),
          relationLoads: [BeakRelationLoad('tags')],
        ),
      );
      expect(withNew.items.single.relations['tags'], hasLength(2));

      await client.detach('products', ReferenceSeedIds.productGrinder, 'tags', [
        ReferenceSeedIds.tagNew,
      ]);
      final withoutNew = await client.query(
        'products',
        const BeakQuerySpec(
          table: 'products',
          filter: BeakFieldFilter.forKey(
            'id',
            BeakOperator.eq,
            BeakStringValue(ReferenceSeedIds.productGrinder),
          ),
          relationLoads: [BeakRelationLoad('tags')],
        ),
      );
      expect(withoutNew.items.single.relations['tags'], hasLength(1));
    });

    test('global search finds records across models', () async {
      if (!guarded()) {
        return;
      }
      final hits = await client.search('Ada');
      expect(
        hits.map((hit) => (hit.table, hit.displayLabel)),
        contains(('users', 'Ada Lovelace')),
      );
    });

    test('exports products as CSV', () async {
      if (!guarded()) {
        return;
      }
      final String csv = await client.export(
        'products',
        const BeakQuerySpec(table: 'products'),
      );
      final List<String> lines = csv.trimRight().split('\r\n');
      expect(lines.first, contains('Name'));
      expect(csv, contains('Espresso Beans'));
    });

    test('computes aggregates over the wire', () async {
      if (!guarded()) {
        return;
      }
      final num count = await client.aggregate(
        'products',
        const BeakAggregateSpec.count(table: 'products'),
      );
      expect(count, greaterThanOrEqualTo(3));
    });
  });
}
