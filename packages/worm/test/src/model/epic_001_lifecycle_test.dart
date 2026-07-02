/// Lifecycle event and hook integration (EPIC-001).
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/event/lifecycle_event.dart';
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

  group('LifecycleEvent enum', () {
    test('defines all expected events', () {
      expect(LifecycleEvent.values, contains(LifecycleEvent.beforeValidate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterValidate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.beforeSave));
      expect(LifecycleEvent.values, contains(LifecycleEvent.beforeCreate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterCreate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.beforeUpdate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterUpdate));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterSave));
      expect(LifecycleEvent.values, contains(LifecycleEvent.beforeDelete));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterDelete));
      expect(LifecycleEvent.values, contains(LifecycleEvent.afterHydrate));
    });

    test('isCancelable returns true for before hooks', () {
      expect(isCancelable(LifecycleEvent.beforeValidate), isTrue);
      expect(isCancelable(LifecycleEvent.beforeSave), isTrue);
      expect(isCancelable(LifecycleEvent.beforeCreate), isTrue);
      expect(isCancelable(LifecycleEvent.beforeUpdate), isTrue);
      expect(isCancelable(LifecycleEvent.beforeDelete), isTrue);
    });

    test('isCancelable returns false for after hooks', () {
      expect(isCancelable(LifecycleEvent.afterValidate), isFalse);
      expect(isCancelable(LifecycleEvent.afterSave), isFalse);
      expect(isCancelable(LifecycleEvent.afterCreate), isFalse);
      expect(isCancelable(LifecycleEvent.afterUpdate), isFalse);
      expect(isCancelable(LifecycleEvent.afterDelete), isFalse);
      expect(isCancelable(LifecycleEvent.afterHydrate), isFalse);
    });
  });

  group('ModelHooks invokeHook', () {
    test('invokes beforeValidate and returns its result', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      final result = await model.invokeHook(LifecycleEvent.beforeValidate);
      expect(result, isTrue);
      expect(log.events, contains('beforeValidate'));
    });

    test('invokeHook can be canceled by returning false', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        log: log,
        cancelBeforeValidate: true,
      );
      final result = await model.invokeHook(LifecycleEvent.beforeValidate);
      expect(result, isFalse);
    });

    test('invokeHook invokes beforeSave', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeHook(LifecycleEvent.beforeSave);
      expect(log.events, contains('beforeSave'));
    });

    test('invokeHook invokes beforeCreate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeHook(LifecycleEvent.beforeCreate);
      expect(log.events, contains('beforeCreate'));
    });

    test('invokeHook invokes beforeUpdate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeHook(LifecycleEvent.beforeUpdate);
      expect(log.events, contains('beforeUpdate'));
    });

    test('invokeHook invokes beforeDelete', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeHook(LifecycleEvent.beforeDelete);
      expect(log.events, contains('beforeDelete'));
    });

    test('invokeHook returns true for non-cancelable events', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      final result = await model.invokeHook(LifecycleEvent.afterValidate);
      expect(result, isTrue);
    });
  });

  group('ModelHooks invokeAfterHook', () {
    test('invokes afterValidate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterValidate);
      expect(log.events, contains('afterValidate'));
    });

    test('invokes afterCreate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterCreate);
      expect(log.events, contains('afterCreate'));
    });

    test('invokes afterUpdate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterUpdate);
      expect(log.events, contains('afterUpdate'));
    });

    test('invokes afterSave', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterSave);
      expect(log.events, contains('afterSave'));
    });

    test('invokes afterDelete', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterDelete);
      expect(log.events, contains('afterDelete'));
    });

    test('invokes afterHydrate', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.afterHydrate);
      expect(log.events, contains('afterHydrate'));
    });

    test('silently ignores non-after events', () async {
      final model = TestModel(tableNameOverride: 'tests', log: log);
      await model.invokeAfterHook(LifecycleEvent.beforeValidate);
      expect(log.events, isEmpty);
    });
  });
}
