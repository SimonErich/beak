/// Observer pattern dispatching.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/event/model_observer.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/observer.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

final class _RecordingObserver extends ModelObserver<TestModel> {
  _RecordingObserver(this.log);

  final HookLog log;

  @override
  Future<bool> beforeValidate(TestModel model) async {
    log.events.add('obs.beforeValidate');
    return true;
  }

  @override
  Future<void> afterValidate(TestModel model) async =>
      log.events.add('obs.afterValidate');

  @override
  Future<bool> beforeSave(TestModel model) async {
    log.events.add('obs.beforeSave');
    return true;
  }

  @override
  Future<bool> beforeCreate(TestModel model) async {
    log.events.add('obs.beforeCreate');
    return true;
  }

  @override
  Future<void> afterCreate(TestModel model) async =>
      log.events.add('obs.afterCreate');

  @override
  Future<void> afterSave(TestModel model) async =>
      log.events.add('obs.afterSave');

  @override
  Future<bool> beforeDelete(TestModel model) async {
    log.events.add('obs.beforeDelete');
    return true;
  }

  @override
  Future<void> afterDelete(TestModel model) async =>
      log.events.add('obs.afterDelete');
}

final class _CancelingObserver extends ModelObserver<TestModel> {
  const _CancelingObserver();

  @override
  Future<bool> beforeCreate(TestModel model) async => false;
}

void main() {
  late InMemoryAdapter adapter;
  late HookLog log;

  Future<void> initWithObservers(List<Observer<Object>> observers) async {
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
      observers: observers,
    );
  }

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'tests'),
    );
    log = HookLog();
  });

  tearDown(Worm.reset);

  group('observer dispatch', () {
    test(
      'observer receives every lifecycle hook for the target type',
      () async {
        await initWithObservers(<Observer<Object>>[_RecordingObserver(log)]);
        final model = TestModel(tableNameOverride: 'tests', log: log)
          ..setAttribute('id', 1)
          ..setAttribute('name', 'Alice');
        await model.save();
        expect(log.events, <String>[
          'beforeValidate',
          'obs.beforeValidate',
          'afterValidate',
          'obs.afterValidate',
          'beforeSave',
          'obs.beforeSave',
          'beforeCreate',
          'obs.beforeCreate',
          'afterCreate',
          'obs.afterCreate',
          'afterSave',
          'obs.afterSave',
        ]);
      },
    );

    test('canceling observer prevents the INSERT', () async {
      await initWithObservers(const <Observer<Object>>[_CancelingObserver()]);
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      final result = await model.save();
      expect(result, isFalse);
      final count = await adapter.count(
        const AggregateDescriptor.count(table: 'tests'),
      );
      expect(count, 0);
    });

    test('observer dispatch covers delete', () async {
      await initWithObservers(<Observer<Object>>[_RecordingObserver(log)]);
      final model = TestModel(tableNameOverride: 'tests')
        ..setAttribute('id', 1)
        ..setAttribute('name', 'Alice');
      await model.save();
      log.events.clear();
      await model.delete();
      expect(log.events, contains('obs.beforeDelete'));
      expect(log.events, contains('obs.afterDelete'));
    });
  });
}
