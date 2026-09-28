import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A minimal environment: enough for [BeakBackendConfig] to resolve.
const Map<String, String> _env = {
  'DATABASE_URL': 'postgres://beak:beak@localhost:25432/beak',
  'PORT': '8099',
  'HOST': '127.0.0.1',
};

/// Records that a customizer ran, so the hook can be asserted on.
final class _RecordingPolicy implements BeakPolicy {
  const _RecordingPolicy();

  @override
  bool canView(BeakPrincipal? principal, String table) => false;

  @override
  bool canCreate(BeakPrincipal? principal, String table) => false;

  @override
  bool canUpdate(BeakPrincipal? principal, String table, Object id) => false;

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) => false;

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    String table,
    String columnKey,
    String storageKey,
  ) => false;
}

/// Refuses every image, so a test can tell this runner was the one used.
final class _RefusingRunner implements BeakTransformRunner {
  const _RefusingRunner();

  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) async => throw const BeakValidationException('refused by the test runner');
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
  });

  tearDown(Worm.reset);

  BeakServeHost host({
    BeakServerCustomizer? configure,
    BeakStorageRegistry Function()? storageRegistry,
    Map<String, String> environment = _env,
    DateTime Function()? now,
  }) => BeakServeHost(
    registry: createApiRegistry(),
    configure: configure,
    storageRegistry: storageRegistry,
    environment: environment,
    now: now,
  );

  Future<Response> send(
    BeakServer server,
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async => server.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      switch (jsonDecode(await response.readAsString())) {
        final Map<String, Object?> map => map,
        final Object? other => throw StateError('expected an object: $other'),
      };

  group('config', () {
    test('resolves host, port and database from the environment', () {
      final config = host().config;
      expect(config.port, 8099);
      expect(config.host, '127.0.0.1');
      expect(config.databaseUrl.host, 'localhost');
    });
  });

  group('buildServer', () {
    test('serves the generated API for every registered model', () async {
      final server = host().buildServer(adapter: adapter);
      final response = await server.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/query'),
          body: jsonEncode(const BeakQuerySpec(table: 'notes').toJson()),
          headers: const {'content-type': 'application/json'},
        ),
      );
      expect(response.statusCode, 200);
    });

    test('wires the registry the host was given', () {
      final server = host().buildServer(adapter: adapter);
      expect(server.registry.byTable('notes'), isNotNull);
    });

    test('passes the storage driver through to uploads', () {
      final server = host().buildServer(
        adapter: adapter,
        storage: BeakMemoryStorageDriver(),
      );
      expect(server.storage, isA<BeakMemoryStorageDriver>());
    });

    test('lets a customizer replace the server it would have built', () async {
      // The escape hatch: same resolved wiring, different policy.
      final server = host(
        configure: (defaults) =>
            defaults.build(policy: const _RecordingPolicy()),
      ).buildServer(adapter: adapter);

      final response = await server.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/query'),
          body: jsonEncode(const BeakQuerySpec(table: 'notes').toJson()),
          headers: const {'content-type': 'application/json'},
        ),
      );
      // 401, not 403: the request carries no principal, so a policy denial
      // means "authenticate first" rather than "you may not".
      expect(response.statusCode, 401, reason: 'the custom policy denied it');
    });

    test('the customizer sees the resolved defaults', () {
      late BeakServerDefaults seen;
      host(
        configure: (defaults) {
          seen = defaults;
          return defaults.build();
        },
      ).buildServer(adapter: adapter);

      expect(seen.registry.byTable('notes'), isNotNull);
      expect(seen.dataSource, isA<WormDataSource>());
      expect(seen.config.port, 8099);
    });
  });

  group('the host clock', () {
    final frozen = DateTime.utc(2031, 5, 6, 7, 8, 9);

    test('stamps the per-record writes', () async {
      final server = host(now: () => frozen).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/notes',
        body: {'title': 'Direct'},
      );

      expect(response.statusCode, 201);
      final created = BeakRecord.fromJson(await bodyOf(response));
      expect(NoteColumns.createdAt.readFrom(created), frozen);
    });

    test('stamps the graph commits', () async {
      final server = host(now: () => frozen).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/commits',
        body: BeakSavePlan(
          saveId: 'clock',
          root: const BeakRecordRef.draft('notes', 'draft'),
          operations: [
            BeakSaveOperation(
              id: 'create',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('notes', 'draft'),
              values: BeakRecord.fromRow({'title': 'Committed'}),
            ),
          ],
        ).toJson(),
      );

      expect(response.statusCode, 200);
      final result = BeakSaveResult.fromJson(await bodyOf(response));
      expect(NoteColumns.createdAt.readFrom(result.rootRecord!), frozen);
    });

    test('survives a customizer that builds its own server', () async {
      // `defaults.build` is the customizer's way in, so the clock must ride
      // along with it rather than being applied after the fact.
      final server = host(
        now: () => frozen,
        configure: (defaults) =>
            defaults.build(policy: const BeakAllowAllPolicy()),
      ).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/notes',
        body: {'title': 'Custom'},
      );

      final created = BeakRecord.fromJson(await bodyOf(response));
      expect(NoteColumns.createdAt.readFrom(created), frozen);
    });
  });

  group('BeakServerDefaults.build', () {
    test('adds middleware and routes around the generated API', () async {
      final seen = <String>[];
      final server = host(
        configure: (defaults) => defaults.build(
          middleware: [
            (inner) => (request) {
              seen.add(request.url.path);
              return inner(request);
            },
          ],
          routes:
              (Router()..get(
                    '/api/ping',
                    (Request request) => Response.ok('{"pong":true}'),
                  ))
                  .call,
        ),
      ).buildServer(adapter: adapter);

      final ping = await send(server, 'GET', '/api/ping');
      final query = await send(
        server,
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'notes').toJson(),
      );

      expect(ping.statusCode, 200);
      expect(query.statusCode, 200);
      expect(seen, ['api/ping', 'api/notes/query']);
    });

    test('configures the CORS origin', () async {
      final server = host(
        configure: (defaults) =>
            defaults.build(corsOrigin: 'https://admin.example'),
      ).buildServer(adapter: adapter);

      final response = await send(server, 'OPTIONS', '/api/notes/query');

      expect(
        response.headers['access-control-allow-origin'],
        'https://admin.example',
      );
    });

    test('mints ids with the given generator', () async {
      final server = host(
        configure: (defaults) => defaults.build(generateId: () => 'minted'),
      ).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/notes',
        body: {'title': 'Direct'},
      );

      final created = BeakRecord.fromJson(await bodyOf(response));
      expect(NoteColumns.id.readFrom(created), 'minted');
    });

    test('closes the per-record routes of graphOnly models', () async {
      final server = host(
        configure: (defaults) => defaults.build(
          preparePlan: (plan, source, principal) async => plan,
          graphOnly: const [NoteModel()],
        ),
      ).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/notes',
        body: {'title': 'Direct'},
      );

      expect(response.statusCode, 422);
    });

    test('runs uploads through the given transform runner', () async {
      final server = host(
        configure: (defaults) =>
            defaults.build(transformRunner: const _RefusingRunner()),
      ).buildServer(adapter: adapter, storage: BeakMemoryStorageDriver());

      const boundary = 'beak-host-boundary';
      final response = await server.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/avatar/upload'),
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
          body: [
            ...utf8.encode(
              '--$boundary\r\n'
              'content-disposition: form-data; name="file"; '
              'filename="photo.png"\r\n'
              'content-type: image/png\r\n\r\n',
            ),
            ...const [0x89, 0x50, 0x4e, 0x47],
            ...utf8.encode('\r\n--$boundary--\r\n'),
          ],
        ),
      );

      expect(response.statusCode, 422);
      expect(await response.readAsString(), contains('refused by the test'));
    });

    test('carries the outbox schedule to the server', () {
      const schedule = BeakOutboxSchedule(handlers: {});
      final server = host(
        configure: (defaults) => defaults.build(outbox: schedule),
      ).buildServer(adapter: adapter);

      expect(server.outbox, same(schedule));
    });

    test('exposes the adapter the data source writes through', () {
      late BeakServerDefaults seen;
      host(
        configure: (defaults) {
          seen = defaults;
          return defaults.build();
        },
      ).buildServer(adapter: adapter);

      expect(seen.dataSource.adapter, same(adapter));
    });
  });

  group('resolveStorageDriver', () {
    test('falls back to local disk when nothing is configured', () {
      // The same posture as the database: an upload column works on a fresh
      // project with no setup, and this server serves what it stored.
      final BeakStorageDriver? driver = host().resolveStorageDriver();

      expect(driver, isA<BeakLocalDiskStorageDriver>());
      if (driver case final BeakLocalDiskStorageDriver local) {
        expect(local.publicBaseUrl.path, BeakServeHost.defaultUploadPath);
        expect(local.rootDir, BeakServeHost.defaultUploadDir);
        // The test environment binds 127.0.0.1, so that is what the URL
        // names; the `0.0.0.0` case is covered below.
        expect(local.publicBaseUrl.host, '127.0.0.1');
      }
    });

    test('never hands out a URL naming the wildcard bind address', () {
      // `0.0.0.0` is where the socket binds, not somewhere a browser can go;
      // a URL built from it would be handed out and then fail to load.
      final BeakStorageDriver? driver = host(
        environment: {..._env, 'HOST': '0.0.0.0'},
      ).resolveStorageDriver();

      expect(driver, isA<BeakLocalDiskStorageDriver>());
      if (driver case final BeakLocalDiskStorageDriver local) {
        expect(local.publicBaseUrl.host, 'localhost');
      }
    });

    test('returns null when the environment turns uploads off', () {
      expect(
        host(
          environment: {..._env, 'BEAK_STORAGE_DRIVER': 'none'},
        ).resolveStorageDriver(),
        isNull,
      );
    });

    test('resolves an in-box driver without a plug-in registry', () {
      final driver = host(
        environment: {..._env, 'BEAK_STORAGE_DRIVER': 'memory'},
      ).resolveStorageDriver();
      expect(driver, isA<BeakMemoryStorageDriver>());
    });

    test('fails by name when the selected driver is not registered', () {
      // A forgotten registerS3Storage surfaces at boot, not at first upload.
      expect(
        () => host(
          environment: {
            ..._env,
            'BEAK_STORAGE_DRIVER': 's3',
            'BEAK_S3_ENDPOINT': 'http://localhost:29000',
            'BEAK_S3_BUCKET': 'b',
            'BEAK_S3_ACCESS_KEY': 'k',
            'BEAK_S3_SECRET_KEY': 's',
            'BEAK_S3_REGION': 'r',
          },
        ).resolveStorageDriver(),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('s3'),
          ),
        ),
      );
    });

    test('uses the plug-in registry the host was given', () {
      final driver = host(
        environment: {..._env, 'BEAK_STORAGE_DRIVER': 'memory'},
        storageRegistry: BeakStorageRegistry.new,
      ).resolveStorageDriver();
      expect(driver, isA<BeakMemoryStorageDriver>());
    });
  });
}
