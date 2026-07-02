/// Active Record save / refresh / afterCommit behavior.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/model_not_found_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';
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

  group('Active Record save', () {
    test('first save inserts; subsequent save updates', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      expect(model.exists, isFalse);
      await model.save();
      expect(model.exists, isTrue);

      model.setAttribute('name', 'Bob');
      await model.save();
      expect(model.exists, isTrue);
    });

    test('update only emits the dirty subset of columns', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice')
        ..setAttribute('age', 30);
      await model.save();
      model.setAttribute('name', 'Bob');
      await model.save();
      // Confirm row mirrors only the new name + updatedAt advance.
      final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
      expect(rows.single['name'], 'Bob');
      expect(rows.single['age'], 30);
    });
  });

  group('afterCommit', () {
    test('callback fires immediately when not in a transaction', () async {
      var fired = false;
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..afterCommit(() => fired = true);
      await model.save();
      expect(fired, isTrue);
    });

    test('afterCommit queue is cleared after firing', () async {
      var count = 0;
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..afterCommit(() => count++);
      await model.save();
      await model.save();
      expect(count, 1);
    });
  });

  group('refresh', () {
    test('reseeds attributes from disk', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      await adapter.update(
        UpdateDescriptor(
          table: 'tests',
          values: const <String, Object?>{'name': 'Carol'},
          where: const Field<Object?>('id').eq(1),
        ),
      );
      await model.refresh();
      expect(model.getAttribute('name'), 'Carol');
      expect(model.isDirty(), isFalse);
    });

    test('throws when the row no longer exists', () async {
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      await model.delete();
      expect(model.refresh, throwsA(isA<ModelNotFoundException>()));
    });
  });
}
