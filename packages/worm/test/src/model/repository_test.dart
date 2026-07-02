/// `Repository<T>` base class parity.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/model_not_found_exception.dart';
import 'package:worm/src/model/repository.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

final class TestRepository extends Repository<TestModel> {
  const TestRepository(super.adapter);

  @override
  String get tableName => 'tests';

  @override
  TestModel hydrate(Map<String, Object?> row) {
    final model = TestModel(tableNameOverride: 'tests');
    for (final entry in row.entries) {
      model.hydrateAttribute(entry.key, entry.value);
    }
    return model;
  }
}

void main() {
  late InMemoryAdapter adapter;
  late TestRepository repo;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'tests'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
    repo = TestRepository(adapter);
  });

  tearDown(Worm.reset);

  group('Repository<T>', () {
    test('save inserts a new model', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      final ok = await repo.save(model);
      expect(ok, isTrue);
      expect(model.exists, isTrue);
    });

    test('find returns the hydrated model', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await repo.save(model);
      final loaded = await repo.find(1);
      expect(loaded, isNotNull);
      expect(loaded!.getAttribute('name'), 'Alice');
      expect(loaded.exists, isTrue);
    });

    test('find returns null when no row matches', () async {
      expect(await repo.find(99), isNull);
    });

    test('findOrFail throws ModelNotFoundException on miss', () async {
      expect(() => repo.findOrFail(99), throwsA(isA<ModelNotFoundException>()));
    });

    test('all returns every row', () async {
      for (final id in <int>[1, 2, 3]) {
        await repo.save(
          TestModel(tableNameOverride: 'tests')
            ..setAttribute('id', id)
            ..setAttribute('name', 'name$id'),
        );
      }
      final models = await repo.all();
      expect(models, hasLength(3));
      expect(
        models.map((m) => m.getAttribute('id')),
        containsAll(<int>[1, 2, 3]),
      );
    });

    test('delete removes the row', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await repo.save(model);
      await repo.delete(model);
      expect(await repo.find(1), isNull);
    });

    test('refresh re-reads the row from disk', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await repo.save(model);
      await adapter.update(
        UpdateDescriptor(
          table: 'tests',
          values: const <String, Object?>{'name': 'Bob'},
          where: const Field<Object?>('id').eq(1),
        ),
      );
      await repo.refresh(model);
      expect(model.getAttribute('name'), 'Bob');
    });

    test('deleteById removes by primary key without hydration', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await repo.save(model);
      final count = await repo.deleteById(1);
      expect(count, 1);
      expect(await repo.find(1), isNull);
    });
  });
}
