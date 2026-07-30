import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beak/migrations.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:store/beak/server.g.dart';
import 'package:store/seeders/store_seeder.dart';
import 'package:test/test.dart';

/// Logs [username] in through [client] and returns a client carrying the
/// session token.
Future<BeakClient> asUser(
  BeakClient client,
  String username,
  String password,
) async {
  final BeakSession session = await client.login(
    username: username,
    password: password,
  );
  return BeakClient(
    baseUrl: client.baseUrl,
    tokenProvider: () => session.token,
  );
}

/// A real, decodable PNG — small enough for every upload rule, real enough
/// for the transform pipeline to do something to it.
final Uint8List storeTestPng = img.encodePng(img.Image(width: 8, height: 8));

/// The JSON object a probe answered with.
Map<String, Object?> _probeBody(http.Response response) =>
    switch (jsonDecode(response.body)) {
      final Map<String, Object?> body => body,
      final Object? other => throw StateError('expected an object, got $other'),
    };

/// The store's whole API surface, asserted once and run twice.
///
/// Every claim the README makes about the backend is checked here: paging,
/// sorting, search, eager loading, validation, uploads with variants, soft
/// delete and restore, pivot attach/detach, global search, CSV export,
/// aggregates, optimistic concurrency, the row policy, and the health probes.
///
/// [environmentFor] is the only difference between the two runs: it receives
/// the port the test server bound and returns the environment to run it in.
/// Point `DATABASE_URL` at `sqlite::memory:` with the local-disk upload driver
/// and the suite runs on every pull request in seconds; point it at Postgres
/// and MinIO and the same assertions run against the real thing under the
/// `e2e` tag. A backend that passes one and fails the other is exactly what
/// this shape is for.
void runStoreApiScenario({
  required Map<String, String> Function(int port) environmentFor,
  required String description,
}) {
  group(description, () {
    late DatabaseAdapter adapter;
    late HttpServer httpServer;
    late BeakClient client;
    late BeakClient staff;

    setUpAll(() async {
      // Bind a port first: the local-disk upload driver's public URLs point
      // back at this server, so it has to know its own address.
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final int port = probe.port;
      await probe.close();

      final Map<String, String> environment = {
        ...environmentFor(port),
        'PORT': '$port',
        'HOST': '127.0.0.1',
      };
      final BeakServeHost host = beakHost(environment: environment);
      adapter = adapterFromUrl(host.config.databaseUrl);
      await adapter.connect();
      await MigrationRunner(
        adapter: adapter,
        migrations: host.migrations.toList(),
        seeders: host.seeders,
      ).fresh(seed: true);

      final server = host.buildServer(
        adapter: adapter,
        storage: host.resolveStorageDriver(),
      );
      httpServer = await server.start();
      client = BeakClient(baseUrl: 'http://127.0.0.1:$port');
      staff = await asUser(client, 'ada@example.com', 'espresso');
    });

    tearDownAll(() async {
      client.close();
      staff.close();
      await httpServer.close(force: true);
      await adapter.disconnect();
    });

    test('queries paged, sorted, searched, with relations loaded', () async {
      final page = await client.query(
        'products',
        const BeakQuerySpec(
          table: 'products',
          sorts: [BeakSort('name')],
          pagination: BeakPagination(perPage: 2),
        ),
      );
      expect(page.total, 3);
      expect(page.items, hasLength(2));
      expect(page.items.first['name']?.raw, 'Espresso Beans');

      final searched = await client.query(
        'products',
        const BeakQuerySpec(
          table: 'products',
          search: BeakSearch('espresso', ['name', 'sku']),
          relationLoads: [
            BeakRelationLoad('category'),
            BeakRelationLoad('tags'),
            BeakRelationLoad('roastProfile'),
          ],
        ),
      );
      expect(searched.total, 1);
      final espresso = searched.items.single;
      expect(espresso.relations['category']?.single['name']?.raw, 'Coffee');
      expect(espresso.relations['tags'], hasLength(2));
      expect(
        espresso.relations['roastProfile']?.single['name']?.raw,
        'Sunday dark',
      );
    });

    test(
      'creates with validation: valid succeeds, invalid is a typed 422',
      () async {
        final created = await staff.create(
          'products',
          BeakRecord.fromRow(const {
            'name': 'V60 Dripper',
            'sku': 'GER-V60-02',
            'price': 24.0,
            'stock': 12,
            'featured': false,
            'status': 'published',
            'category_id': StoreSeedIds.categoryGear,
          }),
        );
        expect(created['id']?.raw, isNotNull);
        expect(created['created_at']?.raw, isNotNull);

        await expectLater(
          staff.create('products', BeakRecord.fromRow(const {'price': -1})),
          throwsA(
            isA<BeakValidationException>().having(
              (exception) => exception.fieldErrors.keys,
              'fieldErrors',
              containsAll(['name', 'sku', 'price']),
            ),
          ),
        );
      },
    );

    test('uploads a PNG and stores its thumbnail variant', () async {
      final stored = await staff.upload(
        'products',
        'image',
        BeakUpload(
          filename: 'red.png',
          mimeType: 'image/png',
          bytes: storeTestPng,
        ),
      );

      expect(stored.key, startsWith('products/'));
      expect(stored.variants, contains('thumbnail'));

      final original = await http.get(stored.url);
      expect(original.statusCode, 200);
      expect(original.bodyBytes, isNotEmpty);

      final Uri? thumbnail = stored.variants['thumbnail']?.url;
      expect(thumbnail, isNotNull);
      if (thumbnail != null) {
        expect((await http.get(thumbnail)).statusCode, 200);
      }
    });

    test('updates, soft-deletes, restores, then force-deletes', () async {
      final created = await staff.create(
        'products',
        BeakRecord.fromRow(const {
          'name': 'Fleeting Filter',
          'sku': 'GER-FLT-99',
          'price': 3.5,
          'stock': 1,
          'featured': false,
          'status': 'draft',
        }),
      );
      final Object id = switch (created['id']?.raw) {
        final Object value => value,
        null => fail('created product has no id'),
      };

      final updated = await staff.update(
        'products',
        id,
        BeakRecord.fromRow(const {'name': 'Fleeting Filter v2'}),
      );
      expect(updated['name']?.raw, 'Fleeting Filter v2');

      await staff.delete('products', id);
      expect(await staff.getOne('products', id), isNull);
      final trashed = await staff.query(
        'products',
        const BeakQuerySpec(table: 'products', withTrashed: true),
      );
      expect(trashed.items.map((record) => record['id']?.raw), contains(id));

      final restored = await staff.restore('products', id);
      expect(restored['deleted_at']?.raw, isNull);
      expect(await staff.getOne('products', id), isNotNull);

      await staff.delete('products', id, force: true);
      final afterForce = await staff.query(
        'products',
        const BeakQuerySpec(table: 'products', withTrashed: true),
      );
      expect(
        afterForce.items.map((record) => record['id']?.raw),
        isNot(contains(id)),
      );
    });

    test('attaches and detaches tags through the pivot', () async {
      const grinder = BeakQuerySpec(
        table: 'products',
        filter: BeakFieldFilter.forKey(
          'id',
          BeakOperator.eq,
          BeakStringValue(StoreSeedIds.productGrinder),
        ),
        relationLoads: [BeakRelationLoad('tags')],
      );

      await staff.attach(
        'products',
        StoreSeedIds.productGrinder,
        'tags',
        const [StoreSeedIds.tagNew],
      );
      expect(
        (await client.query(
          'products',
          grinder,
        )).items.single.relations['tags'],
        hasLength(2),
      );

      await staff.detach(
        'products',
        StoreSeedIds.productGrinder,
        'tags',
        const [StoreSeedIds.tagNew],
      );
      expect(
        (await client.query(
          'products',
          grinder,
        )).items.single.relations['tags'],
        hasLength(1),
      );
    });

    test(
      'global search finds records across models, within the policy',
      () async {
        final hits = await staff.search('Ada');
        expect(
          hits.map((hit) => (hit.table, hit.displayLabel)),
          contains(('users', 'Ada Lovelace')),
        );
      },
    );

    test('exports as CSV and computes aggregates over the wire', () async {
      final String csv = await staff.export(
        'products',
        const BeakQuerySpec(table: 'products'),
      );
      expect(csv.trimRight().split('\r\n').first, contains('Name'));
      expect(csv, contains('Espresso Beans'));

      expect(
        await client.aggregate(
          'products',
          const BeakAggregateSpec.count(table: 'products'),
        ),
        greaterThanOrEqualTo(3),
      );
    });

    test('a stale update loses to the one that landed first', () async {
      final created = await staff.create(
        'products',
        BeakRecord.fromRow(const {
          'name': 'Contested',
          'sku': 'GER-CON-01',
          'price': 1.0,
          'stock': 1,
          'featured': false,
          'status': 'draft',
        }),
      );
      final Object id = switch (created['id']?.raw) {
        final Object value => value,
        null => fail('created product has no id'),
      };
      final DateTime stamp = switch (created['updated_at']) {
        final BeakDateTimeValue value => value.value,
        _ => fail('created product has no updated_at'),
      };
      // What a second editor would have read a moment earlier. Dated back
      // deliberately: the check compares whole seconds, so two saves inside
      // one second are not a conflict worth reporting.
      final DateTime stale = stamp.subtract(const Duration(seconds: 5));

      await staff.update(
        'products',
        id,
        BeakRecord.fromRow(const {'name': 'Landed first'}),
      );

      await expectLater(
        staff.update(
          'products',
          id,
          BeakRecord.fromRow(const {'name': 'Too late'}),
          ifUnmodifiedSince: stale,
        ),
        throwsA(isA<BeakConflictException>()),
      );
      expect(
        (await staff.getOne('products', id))?['name']?.raw,
        'Landed first',
      );
    });

    test('the row policy scopes orders and gates deletes', () async {
      // The catalog is public; the orders are not.
      await expectLater(
        client.query('orders', const BeakQuerySpec(table: 'orders')),
        throwsA(isA<BeakAuthenticationException>()),
      );
      expect(
        (await client.query(
          'products',
          const BeakQuerySpec(table: 'products'),
        )).total,
        greaterThan(0),
      );

      final customer = await asUser(client, 'linus@example.com', 'grinder');
      addTearDown(customer.close);

      expect(
        (await staff.query(
          'orders',
          const BeakQuerySpec(table: 'orders'),
        )).total,
        1,
      );
      expect(
        (await customer.query(
          'orders',
          const BeakQuerySpec(table: 'orders'),
        )).total,
        0,
      );

      await expectLater(
        customer.delete('products', StoreSeedIds.productTeaser),
        throwsA(isA<BeakAuthorizationException>()),
      );
    });

    test('answers both platform probes, unauthenticated', () async {
      final Uri base = Uri.parse(client.baseUrl);

      // Liveness decides whether to restart the process, so it answers from
      // the process alone and reads no database: its body carries only the
      // status, never a data-source detail. Readiness decides whether to route
      // traffic, so it is the one that asks the data source, and it reports ok
      // because the seeded database is answering. What each returns while the
      // source is down is pinned in beak_backend's health tests.
      final live = await http.get(base.resolve('/healthz'));
      expect(live.statusCode, 200);
      expect(_probeBody(live), {'status': 'ok'});

      final ready = await http.get(base.resolve('/readyz'));
      expect(ready.statusCode, 200);
      expect(_probeBody(ready), {'status': 'ok'});
    });
  });
}
