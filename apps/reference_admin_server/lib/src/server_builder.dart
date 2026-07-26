import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:reference_admin_models/reference_admin_models.dart';

import 'migrations/reference_migrations.dart';
import 'seeders/reference_seeder.dart';

/// The reference backend, whole: models, migrations, seeders, and the `s3`
/// upload driver this app opts into.
///
/// Everything else — reading `.env`, connecting worm, resolving the storage
/// config, assembling the router, and the migrate/seed CLI — comes from
/// [BeakServeHost]. `bin/reference_admin_server.dart` and `bin/worm.dart` are
/// one line each because of it.
///
/// ```dart
/// Future<void> main() async => referenceHost().serve();
/// ```
BeakServeHost referenceHost({Map<String, String>? environment}) =>
    BeakServeHost(
      registry: buildReferenceRegistry(),
      migrations: referenceMigrations,
      seeders: const [ReferenceSeeder()],
      storageRegistry: referenceStorageRegistry,
      environment: environment,
    );

/// The storage registry this app resolves drivers from: Beak's in-box
/// `memory` and `local` drivers plus the `s3` plug-in that `.env` selects.
///
/// `beak_backend` deliberately does not depend on any driver package, so an
/// app that uploads to S3 declares `beak_storage_s3` and registers it here.
BeakStorageRegistry referenceStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
