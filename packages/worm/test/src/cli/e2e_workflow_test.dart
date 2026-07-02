/// End-to-end CLI workflow: `init` → scaffold model → migrate →
/// seed → programmatic query against the in-memory store.
///
/// Runs entirely in-process. The harness creates a unique
/// temporary project root for the `init` / `make:model` file
/// scaffolding, shares one [`InMemoryAdapter`] between the
/// migration and seed steps, and tears the temp root down on
/// completion. No subprocess, no real database, no
/// build_runner.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/cli/worm_command_runner.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/seeder/seeder_base.dart';

import '_fixtures.dart';

/// Minimal migration that materialises the `users` table the
/// seeder writes into. Uses the high-level [`SchemaDescriptor`]
/// API so the migration is adapter-agnostic — it works against
/// `InMemoryAdapter` without any fluent-facade overhead.
final class _CreateUsersTable extends Migration {
  const _CreateUsersTable();

  @override
  String get name => '20260101_000000_create_users_table';

  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.text),
        SchemaColumn(name: 'email', type: ColumnType.text),
      ],
    ),
  );

  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
  );
}

/// Inserts three deterministic rows so the final query is
/// guaranteed to observe `count > 0`.
final class _UsersSeeder extends Seeder {
  const _UsersSeeder();

  @override
  String get name => 'UsersSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    await adapter.insert(
      _userInsert(id: 1, name: 'Alice', email: 'alice@example.com'),
    );
    await adapter.insert(
      _userInsert(id: 2, name: 'Bob', email: 'bob@example.com'),
    );
    await adapter.insert(
      _userInsert(id: 3, name: 'Carol', email: 'carol@example.com'),
    );
  }
}

InsertDescriptor _userInsert({
  required int id,
  required String name,
  required String email,
}) => InsertDescriptor(
  table: 'users',
  values: <String, Object?>{'id': id, 'name': name, 'email': email},
);

void main() {
  group('E2E CLI workflow', () {
    test('init → make:model → migrate → db:seed → query — full pipeline runs '
        'in-process and ends with a non-empty users table', () async {
      // Harness owns the temp project root and an in-memory
      // adapter the CLI commands and the post-condition query
      // share.
      final harness = TestHarness(
        migrations: const <Migration>[_CreateUsersTable()],
        seeders: const <Seeder>[_UsersSeeder()],
      );
      addTearDown(harness.dispose);
      final runner = WormCommandRunner(harness.build());

      // Step 1 — `worm init`: scaffold project layout.
      final initCode = await runner.run(const <String>['init']);
      expect(initCode, 0, reason: '`init` should exit 0');
      expect(
        Directory('${harness.projectRoot.path}/migrations').existsSync(),
        isTrue,
        reason: '`init` should create the migrations/ directory',
      );
      expect(
        File(
          '${harness.projectRoot.path}/config/worm_config.dart',
        ).existsSync(),
        isTrue,
        reason: '`init` should write the worm_config.dart template',
      );

      // Step 2 — `worm make:model User`: scaffold the model
      // file. The CLI plants files under
      // lib/models/<snake_case>.dart.
      final makeModelCode = await runner.run(const <String>[
        'make:model',
        'User',
      ]);
      expect(makeModelCode, 0, reason: '`make:model User` should exit 0');
      expect(
        File('${harness.projectRoot.path}/lib/models/user.dart').existsSync(),
        isTrue,
        reason: '`make:model User` should write lib/models/user.dart',
      );

      // Step 3 — `worm migrate`: applies the registered
      // [_CreateUsersTable] migration. This is the step that
      // materialises the users table inside the harness's
      // shared in-memory adapter.
      final migrateCode = await runner.run(const <String>['migrate']);
      expect(migrateCode, 0, reason: '`migrate` should exit 0');
      expect(
        harness.out.toString(),
        contains('migrated  20260101_000000_create_users_table'),
        reason: '`migrate` should report the applied migration name',
      );

      // Step 4 — `worm db:seed`: runs the registered
      // [_UsersSeeder]. The harness defaults to
      // Environment.development which the seeder accepts via
      // the default Environment.all match.
      final seedCode = await runner.run(const <String>['db:seed']);
      expect(seedCode, 0, reason: '`db:seed` should exit 0');
      expect(
        harness.out.toString(),
        contains('seeded  UsersSeeder'),
        reason: '`db:seed` should report the seeder name',
      );

      // Step 5 — programmatic query through the same adapter
      // the CLI used. Hits the normal IN-chunked / concurrent
      // query path, exercising the wider stack on the seeded
      // store.
      final rows = await harness.adapter.select(
        const QueryDescriptor(table: 'users'),
      );
      expect(
        rows.length,
        greaterThan(0),
        reason: 'Seeded users must be observable through a normal SELECT.',
      );
      expect(
        rows.length,
        3,
        reason: 'Seeder inserts exactly three deterministic rows.',
      );
      expect(
        rows.map((row) => row['name']),
        containsAll(<String>['Alice', 'Bob', 'Carol']),
      );

      // Final guarantee: every CLI step exited 0. The runner's
      // public signature is `Future<int?>` even though its body
      // never yields null — keep the list typed as nullable so
      // the assertion holds without spuriously asserting
      // non-nullability we already pinned per-step above.
      expect(
        <int?>[initCode, makeModelCode, migrateCode, seedCode],
        everyElement(0),
        reason: 'Each CLI step must return exit code 0.',
      );
    });

    test('workflow is self-contained — temp project root and adapter teardown '
        'leave no persistent side effects', () async {
      // Drive the full workflow inside a captured tempdir so we
      // can assert the harness disposes it cleanly.
      late Directory tempRoot;
      await () async {
        final harness = TestHarness(
          migrations: const <Migration>[_CreateUsersTable()],
          seeders: const <Seeder>[_UsersSeeder()],
        );
        tempRoot = harness.projectRoot;
        try {
          final runner = WormCommandRunner(harness.build());
          expect(await runner.run(const <String>['init']), 0);
          expect(await runner.run(const <String>['make:model', 'User']), 0);
          expect(await runner.run(const <String>['migrate']), 0);
          expect(await runner.run(const <String>['db:seed']), 0);
        } finally {
          harness.dispose();
        }
      }();

      expect(
        tempRoot.existsSync(),
        isFalse,
        reason:
            'TestHarness.dispose() must remove the temp project root, so '
            'CI runs leave no leftover state behind.',
      );
    });
  });
}
