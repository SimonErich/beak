/// Dirty tracking on the Model attribute store.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;

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
  });

  tearDown(Worm.reset);

  group('dirty tracking', () {
    test('setAttribute marks the field dirty', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('name', 'Alice');
      expect(model.isDirty(), isTrue);
      expect(model.isDirty('name'), isTrue);
      expect(model.isDirty('email'), isFalse);
      expect(model.dirtyFields, <String>{'name'});
    });

    test('fresh model is not dirty', () {
      final model = TestModel(tableNameOverride: 'tests');
      expect(model.isDirty(), isFalse);
      expect(model.dirtyFields, isEmpty);
    });

    test('saving an insert clears the dirty state', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      expect(model.isDirty(), isTrue);
      final ok = await model.save();
      expect(ok, isTrue);
      expect(model.isDirty(), isFalse);
      expect(model.dirtyFields, isEmpty);
    });

    test('getOriginal returns pre-modification value', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      expect(model.getOriginal('name'), 'Alice');
      model.setAttribute('name', 'Bob');
      expect(model.isDirty('name'), isTrue);
      expect(model.getOriginal('name'), 'Alice');
      expect(model.getAttribute('name'), 'Bob');
    });

    test('saving an update clears dirty state and syncs originals', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      model.setAttribute('name', 'Bob');
      await model.save();
      expect(model.isDirty(), isFalse);
      expect(model.getOriginal('name'), 'Bob');
    });

    test('setting an attribute to the same value does not mark dirty', () {
      final model = TestModel(tableNameOverride: 'tests')
        ..hydrateAttribute('name', 'Alice')
        ..markPersisted()
        ..setAttribute('name', 'Alice');
      expect(model.isDirty(), isFalse);
    });
  });
}
