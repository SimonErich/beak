import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_core/io.dart';
import 'package:shelf/shelf.dart';
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

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = await createApiTestDatabase();
  });

  tearDown(Worm.reset);

  BeakServeHost host({
    BeakServerCustomizer? configure,
    BeakStorageRegistry Function()? storageRegistry,
    Map<String, String> environment = _env,
  }) => BeakServeHost(
    registry: createApiRegistry(),
    configure: configure,
    storageRegistry: storageRegistry,
    environment: environment,
  );

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
