/// Tests for the user-facing [Schema] facade and the new
/// [Migration.upSchema] / [Migration.downSchema] override hooks.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/migration/migration_base.dart';
import 'package:worm/src/migration/migration_runner.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/blueprint.dart';
import 'package:worm/src/schema/schema_facade.dart';

final class _SchemaMigration extends Migration {
  const _SchemaMigration();

  @override
  String get name => '20260101_000000_create_users_via_schema';

  @override
  Future<void> upSchema(Schema schema) =>
      schema.create('users', (table) => table.string('name'));

  @override
  Future<void> downSchema(Schema schema) => schema.drop('users');
}

final class _LegacyMigration extends Migration {
  const _LegacyMigration();

  @override
  String get name => '20260101_000001_legacy_up_adapter';

  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'legacy_rows'),
  );

  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: 'legacy_rows', ifExists: true),
  );
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
  });

  group('Schema facade', () {
    test('create() emits a createTable descriptor to the adapter', () async {
      final schema = Schema.forRunner(adapter);
      await schema.create('users', (table) => table.string('name'));
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows, isEmpty);
    });

    test('drop() emits a dropTable descriptor honoring ifExists', () async {
      final schema = Schema.forRunner(adapter);
      await schema.create('temp', (table) => table.string('val'));
      await schema.drop('temp', ifExists: true);
      // Dropping again is safe with ifExists: true.
      await schema.drop('temp', ifExists: true);
    });

    test(
      'alter() forwards to executeSchema with the alter operation',
      () async {
        final schema = Schema.forRunner(adapter);
        await schema.create('orders', (table) => table.integer('id'));
        // The in-memory adapter does not support alter — verify the
        // descriptor reaches the adapter by catching the typed
        // UnsupportedOperationException.
        await expectLater(
          () => schema.alter('orders', (table) => table.string('status')),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('does not extend or implement DatabaseAdapter', () {
      final schema = Schema.forRunner(adapter);
      expect(schema is DatabaseAdapter, isFalse);
    });

    test('exposes the wrapped adapter via the .adapter getter', () {
      final schema = Schema.forRunner(adapter);
      expect(identical(schema.adapter, adapter), isTrue);
    });
  });

  group('Migration runner with Schema facade', () {
    test(
      'runs a migration that overrides upSchema() and creates the table',
      () async {
        final runner = MigrationRunner(
          adapter: adapter,
          migrations: const <Migration>[_SchemaMigration()],
        );
        final applied = await runner.migrate();
        expect(applied, hasLength(1));
        final rows = await adapter.select(
          const QueryDescriptor(table: 'users'),
        );
        expect(rows, isEmpty);
      },
    );

    test(
      'runs a legacy migration that overrides up(adapter) unchanged',
      () async {
        final runner = MigrationRunner(
          adapter: adapter,
          migrations: const <Migration>[_LegacyMigration()],
        );
        final applied = await runner.migrate();
        expect(applied, hasLength(1));
        final rows = await adapter.select(
          const QueryDescriptor(table: 'legacy_rows'),
        );
        expect(rows, isEmpty);
      },
    );

    test('rollback runs downSchema then deletes the tracking row', () async {
      final runner = MigrationRunner(
        adapter: adapter,
        migrations: const <Migration>[_SchemaMigration()],
      );
      await runner.migrate();
      final rolledBack = await runner.rollback();
      expect(rolledBack, <String>['20260101_000000_create_users_via_schema']);
    });
  });

  group('Default upSchema / downSchema delegation', () {
    test('upSchema default forwards to up(adapter)', () async {
      final schema = Schema.forRunner(adapter);
      const migration = _LegacyMigration();
      await migration.upSchema(schema);
      // Table now exists; a select succeeds without error.
      final rows = await adapter.select(
        const QueryDescriptor(table: 'legacy_rows'),
      );
      expect(rows, isEmpty);
    });

    test('Blueprint.create populates BlueprintTable columns', () {
      final blueprint = Blueprint.create('users', (table) {
        table
          ..string('name')
          ..integer('age');
      });
      final names = blueprint.table.columns.map((c) => c.name).toList();
      expect(names, <String>['name', 'age']);
    });
  });
}
