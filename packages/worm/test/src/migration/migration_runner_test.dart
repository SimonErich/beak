import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/migration_exception.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/migration/migration_record_store.dart';
import 'package:worm/src/migration/migration_runner.dart';
import 'package:worm/src/migration/migration_status.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/seeder/seeder_base.dart';

final class _RecordingSeeder extends Seeder {
  const _RecordingSeeder();
  @override
  String get name => 'RecordingSeeder';
  @override
  Future<void> run(DatabaseAdapter adapter) async {}
}

final class _CreateUsers extends Migration {
  const _CreateUsers();
  @override
  String get name => '20260101_000000_create_users';
  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.text),
      ],
    ),
  );
  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'users', ifExists: true),
  );
}

final class _CreatePosts extends Migration {
  const _CreatePosts();
  @override
  String get name => '20260101_000001_create_posts';
  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'posts',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
        SchemaColumn(name: 'user_id', type: ColumnType.uuid),
      ],
    ),
  );
  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'posts', ifExists: true),
  );
}

final class _BrokenUp extends Migration {
  const _BrokenUp();
  @override
  String get name => '20260101_000002_broken';
  @override
  Future<void> up(DatabaseAdapter adapter) async {
    throw StateError('boom');
  }

  @override
  Future<void> down(DatabaseAdapter adapter) async {}
}

Future<InMemoryAdapter> _adapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  return adapter;
}

void main() {
  group('MigrationRunner.migrate', () {
    test('applies pending migrations and records them', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );
      final applied = await runner.migrate();
      expect(applied, [
        '20260101_000000_create_users',
        '20260101_000001_create_posts',
      ]);
      final schemas = await adapter.introspectSchema();
      expect(schemas.keys, containsAll(<String>['users', 'posts']));
    });

    test('is idempotent — second call applies nothing', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers()],
      );
      await runner.migrate();
      final again = await runner.migrate();
      expect(again, isEmpty);
    });

    test('wraps up() failures in MigrationException', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_BrokenUp()],
      );
      await expectLater(runner.migrate, throwsA(isA<MigrationException>()));
    });
  });

  group('MigrationRunner.pretend', () {
    test('captures statements without applying them', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers()],
      );
      final captured = await runner.pretend();
      expect(captured.keys, ['20260101_000000_create_users']);
      expect(captured.values.single, isNotEmpty);
      final schemas = await adapter.introspectSchema();
      expect(schemas.containsKey('users'), isFalse);
    });
  });

  group('MigrationRunner.status', () {
    test('reports applied and pending', () async {
      final adapter = await _adapter();
      const migrations = <Migration>[_CreateUsers(), _CreatePosts()];
      final runner = MigrationRunner(adapter: adapter, migrations: migrations);
      await runner.migrate();
      final extended = MigrationRunner(
        adapter: adapter,
        migrations: <Migration>[...migrations, const _BrokenUp()],
      );
      final report = await extended.status();
      expect(report.map((s) => s.state), [
        MigrationState.applied,
        MigrationState.applied,
        MigrationState.pending,
      ]);
    });
  });

  group('MigrationRunner.rollback', () {
    test('reverts last batch in reverse order', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );
      await runner.migrate();
      final reverted = await runner.rollback();
      expect(reverted, [
        '20260101_000001_create_posts',
        '20260101_000000_create_users',
      ]);
      final schemas = await adapter.introspectSchema();
      expect(schemas.keys, isNot(contains('users')));
    });

    test('is a no-op when nothing is applied', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers()],
      );
      final reverted = await runner.rollback();
      expect(reverted, isEmpty);
    });
  });

  group('MigrationRunner.fresh and refresh', () {
    test('fresh re-applies everything from scratch', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers()],
      );
      await runner.fresh();
      final rows = await adapter.select(
        const QueryDescriptor(table: migrationsTable),
      );
      expect(rows, hasLength(1));
    });

    test(
      'repeated fresh drops existing data and reruns tracked seeders',
      () async {
        final adapter = await _adapter();
        final runner = MigrationRunner(
          adapter: adapter,
          migrations: const [_CreateUsers(), _CreatePosts()],
          seeders: const [_RecordingSeeder()],
        );
        expect(await runner.fresh(seed: true), ['RecordingSeeder']);
        await adapter.insert(
          const InsertDescriptor(
            table: 'users',
            values: {'id': 'old', 'name': 'Removed'},
          ),
        );
        expect(await runner.fresh(seed: true), ['RecordingSeeder']);
        expect(
          await adapter.select(const QueryDescriptor(table: 'users')),
          isEmpty,
        );
        expect(
          await adapter.select(const QueryDescriptor(table: migrationsTable)),
          hasLength(2),
        );
      },
    );

    test(
      'unknown migration rejects before deleting known tables or history',
      () async {
        final adapter = await _adapter();
        await MigrationRunner(
          adapter: adapter,
          migrations: const [_CreateUsers(), _CreatePosts()],
        ).migrate();
        final incomplete = MigrationRunner(
          adapter: adapter,
          migrations: const [_CreateUsers()],
        );
        await expectLater(incomplete.fresh, throwsA(isA<MigrationException>()));
        expect(
          (await adapter.introspectSchema()).keys,
          containsAll(['users', 'posts']),
        );
        expect(
          await adapter.select(const QueryDescriptor(table: migrationsTable)),
          hasLength(2),
        );
      },
    );

    test('refresh rolls back every batch and re-applies', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );
      await runner.migrate();
      await runner.refresh();
      final schemas = await adapter.introspectSchema();
      expect(schemas.keys, containsAll(<String>['users', 'posts']));
    });

    test(
      'fresh(seed: true) runs registered seeders and returns names',
      () async {
        final adapter = await _adapter();
        final runner = MigrationRunner(
          adapter: adapter,
          migrations: const <Migration>[_CreateUsers()],
          seeders: const <Seeder>[_RecordingSeeder()],
        );

        final seeded = await runner.fresh(seed: true);

        expect(seeded, <String>['RecordingSeeder']);
      },
    );

    test('fresh(seed: false) does not run seeders', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers()],
        seeders: const <Seeder>[_RecordingSeeder()],
      );

      final seeded = await runner.fresh();

      expect(seeded, isEmpty);
    });
  });

  group('MigrationRunner.run alias', () {
    test('run(step: N) forwards to migrate(step: N)', () async {
      final adapter = await _adapter();
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_CreateUsers(), _CreatePosts()],
      );

      final applied = await runner.run(step: 1);

      expect(applied, <String>['20260101_000000_create_users']);
      final schemas = await adapter.introspectSchema();
      expect(schemas.containsKey('users'), isTrue);
      expect(schemas.containsKey('posts'), isFalse);
    });
  });
}
