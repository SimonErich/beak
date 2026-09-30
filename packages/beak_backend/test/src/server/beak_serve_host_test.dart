import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:beak_test/beak_test.dart';
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
  bool canView(BeakPrincipal? principal, BeakModel model) => false;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => false;

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) => false;

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) => false;

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => false;
}

/// Refuses every image, so a test can tell this runner was the one used.
final class _RefusingRunner implements BeakTransformRunner {
  const _RefusingRunner();

  @override
  Future<BeakDimensions> inspect(Uint8List source) async =>
      const BeakDimensions.square(1);

  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) async => throw const BeakValidationException('refused by the test runner');
}

/// A driver that signs links: the URL it hands out carries the lifetime it
/// was asked for, the way a presigning S3 driver does.
final class _SigningStorage implements BeakStorageDriver {
  _SigningStorage() : _files = BeakMemoryStorageDriver();

  final BeakMemoryStorageDriver _files;

  @override
  String get id => 'signing';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) =>
      _files.put(upload, path: path);

  @override
  Future<Uint8List> get(String key) => _files.get(key);

  @override
  Future<void> delete(String key) => _files.delete(key);

  @override
  Future<bool> exists(String key) => _files.exists(key);

  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    final Uri base = await _files.url(key);
    return expiresIn == null
        ? base
        : base.replace(
            queryParameters: {'expiresInSeconds': '${expiresIn.inSeconds}'},
          );
  }
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

    test('serves a storage driver handed to build', () {
      final custom = BeakMemoryStorageDriver();
      final server = host(
        configure: (defaults) => defaults.build(storage: custom),
      ).buildServer(adapter: adapter, storage: BeakMemoryStorageDriver());

      expect(server.storage, same(custom));
    });

    test('keeps the resolved storage driver when none is handed over', () {
      final resolved = BeakMemoryStorageDriver();
      final server = host(
        configure: (defaults) => defaults.build(),
      ).buildServer(adapter: adapter, storage: resolved);

      expect(server.storage, same(resolved));
    });

    test('serves a data source handed to build', () async {
      final registry = createApiRegistry();
      final source = InMemoryBeakDataSource(registry: registry)
        ..seed(const NoteModel(), [
          BeakRecord.fromRow({'id': 'n1', 'title': 'From memory'}),
        ]);
      final server = host(
        configure: (defaults) => defaults.build(dataSource: source),
      ).buildServer(adapter: adapter);

      final response = await send(
        server,
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'notes').toJson(),
      );

      expect(server.dataSource, same(source));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), contains('From memory'));
    });

    test('signs upload links for the configured lifetime', () async {
      Future<Map<String, Object?>> signedLink(
        BeakServerCustomizer configure,
      ) async {
        final server = host(
          configure: configure,
        ).buildServer(adapter: adapter, storage: _SigningStorage());
        const boundary = 'beak-signed-boundary';
        final uploaded = await server.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/notes/attachment/upload'),
            headers: {
              'content-type': 'multipart/form-data; boundary=$boundary',
            },
            body: [
              ...utf8.encode(
                '--$boundary\r\n'
                'content-disposition: form-data; name="file"; '
                'filename="a.pdf"\r\n'
                'content-type: application/pdf\r\n\r\n',
              ),
              ...utf8.encode('%PDF-1.4'),
              ...utf8.encode('\r\n--$boundary--\r\n'),
            ],
          ),
        );
        final stored = await bodyOf(uploaded);
        final Object? key = stored['key'];
        return bodyOf(
          await send(
            server,
            'GET',
            '/api/notes/attachment/upload?key=${Uri.encodeQueryComponent('$key')}',
          ),
        );
      }

      final defaulted = await signedLink((defaults) => defaults.build());
      final custom = await signedLink(
        (defaults) =>
            defaults.build(signedUrlLifetime: const Duration(minutes: 5)),
      );

      expect('${defaulted['url']}', contains('expiresInSeconds=3600'));
      expect('${custom['url']}', contains('expiresInSeconds=300'));
    });

    test('serves pages no larger than maxPerPage', () async {
      final server = host(
        configure: (defaults) => defaults.build(maxPerPage: 2),
      ).buildServer(adapter: adapter);
      for (final title in ['a', 'b', 'c']) {
        await send(server, 'POST', '/api/notes', body: {'title': title});
      }

      final response = await send(
        server,
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(
          table: 'notes',
          pagination: BeakPagination(perPage: 100),
        ).toJson(),
      );
      final body = await bodyOf(response);

      expect(body['items'], hasLength(2));
      expect(body['perPage'], 2);
      expect(body['total'], 3);
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
