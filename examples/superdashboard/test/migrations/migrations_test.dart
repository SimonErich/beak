import 'package:superdashboard/beak/registry.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beak/migrations.dart';
import 'package:superdashboard/beak/server.g.dart';

void main() {
  group('schema parity', () {
    test('every model column becomes a migration column', () {
      for (final model in beakModels) {
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
      for (final model in beakModels.where((model) => model.softDeletes)) {
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
      for (final model in beakModels) {
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
    test('has ten migrations with unique, ordered names', () {
      expect(beakHost().migrations, hasLength(10));
      final names = beakHost().migrations.map((m) => m.name).toList();
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
      // upSchema (column building, index and foreign-key declarations)
      // executes cleanly and the dependency sorter accepts all ten; real
      // constraint enforcement is covered by the Postgres E2E.
      final adapter = InMemoryAdapter();
      await adapter.connect();
      addTearDown(adapter.disconnect);

      final runner = MigrationRunner(
        adapter: adapter,
        migrations: beakHost().migrations,
      );
      await runner.fresh();

      expect(runner.migrations, hasLength(10));
    });
  });
}
