@TestOn('vm')
library;

import 'package:beak/migrations.dart';
import 'package:showcase/beak/server.g.dart';
import 'package:test/test.dart';

void main() {
  test('every migration rolls back and applies again', () async {
    final host = beakHost(
      environment: const {
        'DATABASE_URL': 'sqlite::memory:',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    final adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    addTearDown(() async {
      await adapter.disconnect();
      await Worm.reset();
    });
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
    );

    final applied = await runner.migrate();
    expect(applied, hasLength(host.migrations.length));

    final rolledBack = await runner.rollback();
    expect(rolledBack, unorderedEquals(applied));
    expect((await runner.status()).map((status) => status.state).toSet(), {
      MigrationState.pending,
    });

    await runner.refresh();
    expect((await runner.status()).map((status) => status.state).toSet(), {
      MigrationState.applied,
    });
  });

  test('migrations run in the order their names declare', () {
    final host = beakHost(
      environment: const {
        'DATABASE_URL': 'sqlite::memory:',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    final names = [for (final migration in host.migrations) migration.name];

    expect(names, [...names]..sort());
    expect(names.toSet(), hasLength(names.length));
  });
}
