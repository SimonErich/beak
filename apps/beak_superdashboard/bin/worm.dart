import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_superdashboard/migrations/demo_migrations.dart';
import 'package:beak_superdashboard/seeders/demo_database_seeder.dart';
import 'package:worm/worm.dart';

/// The project-aware worm CLI: registers every superdashboard migration and
/// the master seeder, connecting to the Postgres database `DATABASE_URL`
/// points at.
///
/// Run `dart run bin/worm.dart migrate` or `dart run bin/worm.dart db:seed`.
Future<void> main(List<String> args) async {
  final config = BeakBackendConfig.fromEnv(environment: BeakEnv.resolve());
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment,
    now: DateTime.now,
    adapterFactory: () async {
      final adapter = postgresAdapterFromUrl(config.databaseUrl);
      await adapter.connect();
      return adapter;
    },
    migrations: demoMigrations,
    seeders: const [DemoDatabaseSeeder()],
  );
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
