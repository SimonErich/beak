/// Lifecycle hook ordering and cancellation.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;
  late HookLog log;

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
    log = HookLog();
  });

  tearDown(Worm.reset);

  group('lifecycle event order', () {
    test('INSERT fires hooks in the documented order', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      expect(log.events, <String>[
        'beforeValidate',
        'afterValidate',
        'beforeSave',
        'beforeCreate',
        'afterCreate',
        'afterSave',
      ]);
    });

    test('UPDATE fires hooks in the documented order', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      log.events.clear();
      model.setAttribute('name', 'Bob');
      await model.save();
      expect(log.events, <String>[
        'beforeValidate',
        'afterValidate',
        'beforeSave',
        'beforeUpdate',
        'afterUpdate',
        'afterSave',
      ]);
    });

    test('DELETE fires beforeDelete then afterDelete', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      log.events.clear();
      await model.delete();
      expect(log.events, <String>['beforeDelete', 'afterDelete']);
    });
  });

  group('cancellation by returning false', () {
    test('beforeValidate cancels and skips every later hook', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        log: log,
        cancelBeforeValidate: true,
      )..setAttribute('id', 1);
      final result = await model.save();
      expect(result, isFalse);
      expect(log.events, <String>['beforeValidate']);
      final count = await adapter.count(
        const AggregateDescriptor.count(table: 'tests'),
      );
      expect(count, 0);
    });

    test('beforeSave cancels and prevents the database call', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        log: log,
        cancelBeforeSave: true,
      )..setAttribute('id', 1);
      final result = await model.save();
      expect(result, isFalse);
      expect(log.events, <String>[
        'beforeValidate',
        'afterValidate',
        'beforeSave',
      ]);
      final count = await adapter.count(
        const AggregateDescriptor.count(table: 'tests'),
      );
      expect(count, 0);
    });

    test('beforeCreate cancels and prevents INSERT', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        log: log,
        cancelBeforeCreate: true,
      )..setAttribute('id', 1);
      final result = await model.save();
      expect(result, isFalse);
      expect(log.events, <String>[
        'beforeValidate',
        'afterValidate',
        'beforeSave',
        'beforeCreate',
      ]);
      final count = await adapter.count(
        const AggregateDescriptor.count(table: 'tests'),
      );
      expect(count, 0);
    });

    test('beforeUpdate cancels and prevents UPDATE', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      log.events.clear();
      model
        ..cancelBeforeUpdate = true
        ..setAttribute('name', 'Bob');
      final result = await model.save();
      expect(result, isFalse);
      expect(log.events, <String>[
        'beforeValidate',
        'afterValidate',
        'beforeSave',
        'beforeUpdate',
      ]);
    });

    test('beforeDelete cancels and prevents DELETE', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      log.events.clear();
      model.cancelBeforeDelete = true;
      final result = await model.delete();
      expect(result, isFalse);
      expect(log.events, <String>['beforeDelete']);
      final count = await adapter.count(
        const AggregateDescriptor.count(table: 'tests'),
      );
      expect(count, 1);
    });
  });
}
