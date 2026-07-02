/// Unit tests for the lifecycle event dispatcher.
library;

import 'package:test/test.dart';
import 'package:worm/src/event/event_dispatcher.dart';
import 'package:worm/src/event/lifecycle_event.dart';
import 'package:worm/src/event/lifecycle_handler.dart';
import 'package:worm/src/model/model.dart';

import '../model/_fixtures.dart';

final class _RecordingHandler implements LifecycleHandler {
  _RecordingHandler(this.log, {this.cancelOn});

  final HookLog log;
  final LifecycleEvent? cancelOn;

  @override
  Future<bool> dispatchBefore(LifecycleEvent event, Model model) async {
    log.events.add('h.${event.name}');
    return event != cancelOn;
  }

  @override
  Future<void> dispatchAfter(LifecycleEvent event, Model model) async {
    log.events.add('h.${event.name}');
  }
}

void main() {
  group('EventDispatcher', () {
    test('invokes the model hook first and every handler in order', () async {
      final log = HookLog();
      final dispatcher = EventDispatcher(<LifecycleHandler>[
        _RecordingHandler(log),
        _RecordingHandler(log),
      ]);
      final model = TestModel(tableNameOverride: 'tests', log: log);
      final ok = await dispatcher.dispatchBefore(
        LifecycleEvent.beforeSave,
        model,
      );
      expect(ok, isTrue);
      expect(log.events, <String>[
        'beforeSave',
        'h.beforeSave',
        'h.beforeSave',
      ]);
    });

    test('handler returning false stops the chain', () async {
      final log = HookLog();
      final dispatcher = EventDispatcher(<LifecycleHandler>[
        _RecordingHandler(log, cancelOn: LifecycleEvent.beforeCreate),
        _RecordingHandler(log),
      ]);
      final model = TestModel(tableNameOverride: 'tests', log: log);
      final ok = await dispatcher.dispatchBefore(
        LifecycleEvent.beforeCreate,
        model,
      );
      expect(ok, isFalse);
      expect(log.events, <String>['beforeCreate', 'h.beforeCreate']);
    });

    test('dispatchBefore throws on non-cancelable events', () {
      const dispatcher = EventDispatcher(<LifecycleHandler>[]);
      final model = TestModel(tableNameOverride: 'tests');
      expect(
        () => dispatcher.dispatchBefore(LifecycleEvent.afterSave, model),
        throwsArgumentError,
      );
    });

    test('dispatchAfter throws on cancelable events', () {
      const dispatcher = EventDispatcher(<LifecycleHandler>[]);
      final model = TestModel(tableNameOverride: 'tests');
      expect(
        () => dispatcher.dispatchAfter(LifecycleEvent.beforeSave, model),
        throwsArgumentError,
      );
    });
  });
}
