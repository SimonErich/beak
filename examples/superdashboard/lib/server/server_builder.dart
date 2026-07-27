import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:superdashboard/migrations/demo_migrations.dart';
import 'package:superdashboard/models/models.dart';
import 'package:superdashboard/seeders/demo_database_seeder.dart';

/// The superdashboard backend, whole: 49 models, their migrations, the master
/// seeder, and the `s3` upload driver this demo opts into.
///
/// Everything else — reading `.env`, connecting worm, resolving the storage
/// config, assembling the router for every model, and the migrate/seed CLI —
/// comes from [BeakServeHost].
///
/// The demo defaults to port `8180` (the panel's `apiBaseUrl`; 8080–8082 are
/// commonly taken). A real `PORT`, from `.env` or the environment, still wins.
BeakServeHost demoHost({Map<String, String>? environment}) => BeakServeHost(
  registry: buildDemoRegistry(),
  migrations: demoMigrations,
  seeders: const [DemoDatabaseSeeder()],
  storageRegistry: demoStorageRegistry,
  environment: {'PORT': '8180', ...environment ?? BeakEnv.resolve()},
);

/// The storage registry this app resolves drivers from: Beak's in-box
/// `memory` and `local` drivers plus the `s3` plug-in that `.env` selects.
///
/// `beak_backend` deliberately does not depend on any driver package, so an
/// app that uploads to S3 declares `beak_storage_s3` and registers it here.
BeakStorageRegistry demoStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
