/// Worm.withoutEvents lifecycle muting.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/event/lifecycle_event.dart';
import 'package:worm/src/exception/validation_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';
import 'package:worm/src/validation/rules/required_rule.dart';
import 'package:worm/src/validation/validation_rule.dart';

import '../model/_fixtures.dart';

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

  group('Worm.withoutEvents', () {
    test('mutes every lifecycle hook by default', () async {
      final log = HookLog();
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1);
      await Worm.withoutEvents(model.save);
      expect(log.events, isEmpty);
      // The write itself still happened.
      final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
      expect(rows, hasLength(1));
    });

    test('selective muting skips only the named events', () async {
      final log = HookLog();
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1);
      await Worm.withoutEvents(
        model.save,
        events: <LifecycleEvent>[LifecycleEvent.afterCreate],
      );
      expect(log.events, contains('beforeCreate'));
      expect(log.events, isNot(contains('afterCreate')));
    });

    test('muting propagates across awaits', () async {
      final log = HookLog();
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1);
      await Worm.withoutEvents(() async {
        await Future<void>.delayed(Duration.zero);
        await model.save();
      });
      expect(log.events, isEmpty);
    });

    test('nested muting unions the muted sets', () async {
      final log = HookLog();
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1);
      await Worm.withoutEvents(
        () => Worm.withoutEvents(
          model.save,
          events: <LifecycleEvent>[LifecycleEvent.afterCreate],
        ),
        events: <LifecycleEvent>[LifecycleEvent.beforeCreate],
      );
      expect(log.events, isNot(contains('beforeCreate')));
      expect(log.events, isNot(contains('afterCreate')));
    });

    test('an inner mute-all overrides an outer partial mute', () async {
      final log = HookLog();
      final model = TestModel(tableNameOverride: 'tests', log: log)
        ..setAttribute('id', 1);
      await Worm.withoutEvents(
        () => Worm.withoutEvents(model.save),
        events: <LifecycleEvent>[LifecycleEvent.afterCreate],
      );
      expect(log.events, isEmpty);
    });

    test('a muted beforeDelete does not cancel the delete', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        cancelBeforeDelete: true,
      )..setAttribute('id', 1);
      await model.save();
      // beforeDelete would normally cancel, but muting skips it.
      final deleted = await Worm.withoutEvents(model.delete);
      expect(deleted, isTrue);
      final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
      expect(rows, isEmpty);
    });

    test('validation still runs while events are muted', () async {
      final model = TestModel(
        tableNameOverride: 'tests',
        rulesOverride: <Field<Object?>, List<ValidationRule>>{
          const Field<Object?>('name'): const <ValidationRule>[Required()],
        },
      )..setAttribute('id', 1);
      await expectLater(
        () => Worm.withoutEvents(model.save),
        throwsA(isA<ValidationException>()),
      );
    });

    test('isEventMuted is zone-only and safe before initialize', () async {
      await Worm.reset();
      expect(Worm.isEventMuted(LifecycleEvent.beforeCreate), isFalse);
      await Worm.withoutEvents(() async {
        expect(Worm.isEventMuted(LifecycleEvent.beforeCreate), isTrue);
      });
    });
  });
}
