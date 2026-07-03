import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:reference_admin_models/reference_admin_models.dart';
import 'package:reference_admin_server/reference_admin_server.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
  });

  Future<List<Map<String, Object?>>> rowsOf(String table) =>
      adapter.select(QueryDescriptor(table: table));

  group('migrations', () {
    test('apply in order and are recorded once', () async {
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: referenceMigrations.toList(),
      );

      final List<String> applied = await runner.migrate();
      expect(applied, [
        for (final migration in referenceMigrations) migration.name,
      ]);

      expect(await runner.migrate(), isEmpty, reason: 'idempotent');
    });

    test('roll back cleanly', () async {
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: referenceMigrations.toList(),
      );
      await runner.migrate();

      final List<String> rolledBack = await runner.rollback(
        steps: referenceMigrations.length,
      );
      expect(rolledBack, hasLength(referenceMigrations.length));
    });
  });

  group('seeder', () {
    test('populates the deterministic catalog', () async {
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: referenceMigrations.toList(),
      );
      await runner.migrate();
      await const ReferenceSeeder().run(adapter);

      expect(await rowsOf('categories'), hasLength(2));
      expect(await rowsOf('tags'), hasLength(3));
      expect(await rowsOf('users'), hasLength(2));
      expect(await rowsOf('products'), hasLength(3));
      expect(await rowsOf('product_tag'), hasLength(3));
      expect(await rowsOf('orders'), hasLength(1));
      expect(await rowsOf('order_items'), hasLength(2));
    });

    test('seeded data serves the full Beak surface over worm', () async {
      Worm.seedRandom(42);
      await Worm.initialize(
        config: const WormConfig(),
        adapters: {'default': adapter},
      );
      addTearDown(Worm.reset);
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: referenceMigrations.toList(),
      );
      await runner.migrate();
      await const ReferenceSeeder().run(adapter);

      final registry = buildReferenceRegistry();
      final dataSource = WormDataSource(registry, adapter: adapter);

      final page = await dataSource.query(
        const BeakQuerySpec(
          table: 'products',
          relationLoads: [
            BeakRelationLoad('category'),
            BeakRelationLoad('tags'),
          ],
        ),
      );
      expect(page.total, 3);
      final espresso = page.items.firstWhere(
        (record) =>
            record['id'] ==
            const BeakStringValue(ReferenceSeedIds.productEspresso),
      );
      expect(
        espresso.relations['category']?.single['name'],
        const BeakStringValue('Coffee'),
      );
      expect(espresso.relations['tags'], hasLength(2));
    });
  });

  group('storage config', () {
    test('reads the s3 selection from the environment', () {
      final config = referenceStorageConfig(const {
        'BEAK_STORAGE_DRIVER': 's3',
        'BEAK_S3_ENDPOINT': 'http://localhost:29000',
        'BEAK_S3_BUCKET': 'beak-uploads',
        'BEAK_S3_ACCESS_KEY': 'beak',
        'BEAK_S3_SECRET_KEY': 'beaksecret',
        'BEAK_S3_REGION': 'us-east-1',
        'BEAK_S3_USE_PATH_STYLE': 'true',
      });

      expect(config, isA<BeakS3Config>());
      if (config case final BeakS3Config s3) {
        expect(s3.bucket, 'beak-uploads');
        expect(s3.usePathStyle, isTrue);
      }
    });

    test('memory and absent selections resolve accordingly', () {
      expect(
        referenceStorageConfig(const {'BEAK_STORAGE_DRIVER': 'memory'}),
        isA<BeakMemoryStorageConfig>(),
      );
      expect(referenceStorageConfig(const {}), isNull);
    });

    test('a missing s3 variable is a configuration error', () {
      expect(
        () => referenceStorageConfig(const {'BEAK_STORAGE_DRIVER': 's3'}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('an unknown driver is a configuration error', () {
      expect(
        () => referenceStorageConfig(const {'BEAK_STORAGE_DRIVER': 'carrier'}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('server builder', () {
    test('assembles a bootable server over the shared registry', () async {
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final int freePort = probe.port;
      await probe.close();

      final server = buildReferenceServer(
        config: BeakBackendConfig.fromEnv(
          environment: {
            'DATABASE_URL': 'postgres://beak:beak@localhost:25432/beak',
            'PORT': '$freePort',
            'HOST': '127.0.0.1',
          },
        ),
        adapter: adapter,
      );

      final httpServer = await server.start();
      addTearDown(() => httpServer.close(force: true));
      expect(httpServer.port, freePort);
    });
  });
}
