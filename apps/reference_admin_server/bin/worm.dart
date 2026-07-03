import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:reference_admin_server/reference_admin_server.dart';
import 'package:worm/worm.dart';

/// The project-aware worm CLI: registers every reference migration and
/// seeder, connecting to the Postgres database `DATABASE_URL` points at.
///
/// Run e.g. `dart run bin/worm.dart migrate` or
/// `dart run bin/worm.dart db:seed`.
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
    migrations: referenceMigrations,
    seeders: const [ReferenceSeeder()],
  );
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
