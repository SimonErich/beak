import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_superdashboard/migrations/demo_migrations.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worm/worm.dart';

void main() {
  group('schema parity', () {
    test('every model column becomes a migration column', () {
      for (final model in demoModels) {
        final blueprint = Blueprint.create(
          model.table,
          (table) => BeakBlueprint.defineColumns(table, model),
        );
        final columnNames = {
          for (final column in blueprint.table.columns) column.name,
        };
        final modelKeys = {for (final column in model.columns) column.key};

        expect(
          columnNames,
          containsAll(modelKeys),
          reason:
              '${model.table} migration is missing '
              '${modelKeys.difference(columnNames)}',
        );
      }
    });

    test('soft-deleting models get a deleted_at column', () {
      for (final model in demoModels.where((model) => model.softDeletes)) {
        final blueprint = Blueprint.create(
          model.table,
          (table) => BeakBlueprint.defineColumns(table, model),
        );
        final columnNames = {
          for (final column in blueprint.table.columns) column.name,
        };
        expect(columnNames, contains('deleted_at'));
      }
    });

    test('foreign-key columns are declared for every belongs-to', () {
      for (final model in demoModels) {
        final blueprint = Blueprint.create(
          model.table,
          (table) => BeakBlueprint.defineColumns(table, model),
        );
        final columnNames = {
          for (final column in blueprint.table.columns) column.name,
        };
        for (final relation in model.relationships) {
          if (relation is BeakBelongsTo) {
            expect(
              columnNames,
              contains(relation.foreignKey),
              reason: '${model.table} lacks FK column ${relation.foreignKey}',
            );
          }
        }
      }
    });
  });

  group('migration set', () {
    test('has eleven migrations with unique, ordered names', () {
      expect(demoMigrations, hasLength(11));
      final names = demoMigrations.map((m) => m.name).toList();
      expect(names.toSet(), hasLength(names.length));
      final sorted = [...names]..sort();
      expect(
        names,
        sorted,
        reason: 'migration names must be lexically ordered',
      );
    });

    test('every up/down schema builds without error in-memory', () async {
      // The in-memory adapter is schemaless, so this proves every migration's
      // upSchema (column building, index/FK declarations) executes cleanly —
      // including the raw-SQL companion migration degrading to a no-op — and
      // the dependency sorter accepts all eleven; real constraint enforcement
      // is covered by the Postgres E2E.
      final adapter = InMemoryAdapter();
      await adapter.connect();
      addTearDown(adapter.disconnect);

      final runner = MigrationRunner(
        adapter: adapter,
        migrations: demoMigrations,
      );
      await runner.fresh();

      expect(runner.migrations, hasLength(11));
    });
  });
}
