import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_frontend/src/data/model_beak_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/panel_fixtures.dart';

void main() {
  test(
    'one subscribed timer pauses in background and refreshes on resume',
    () async {
      final timers = <_ControlledTimer>[];
      await runZoned(
        () async {
          final source = ModelBeakDataSource(
            registry: BeakModelRegistry()..register(const NoteModel()),
            fallback: FakeDataSource(),
            refreshPolicy: const BeakRefreshPolicy(
              interval: Duration(seconds: 1),
            ),
          );
          final first = <BeakDataChange>[];
          final second = <BeakDataChange>[];
          expect(timers, isEmpty);
          final a = source.changes.listen(first.add);
          final b = source.changes.listen(second.add);
          expect(timers, hasLength(1));
          timers.single.fire();
          expect(first, hasLength(1));
          expect(second, hasLength(1));
          expect(first.single.tables, {'notes'});
          source.setForeground(false);
          expect(timers.single.isActive, isFalse);
          timers.single.fire();
          expect(first, hasLength(1));
          source.setForeground(true);
          expect(first, hasLength(2));
          expect(timers, hasLength(2));
          timers.last.fire();
          expect(first, hasLength(3));
          await a.cancel();
          expect(timers.last.isActive, isTrue);
          await b.cancel();
          expect(timers.last.isActive, isFalse);
          await source.dispose();
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            expect(duration, const Duration(seconds: 1));
            final timer = _ControlledTimer(callback);
            timers.add(timer);
            return timer;
          },
        ),
      );
    },
  );

  test(
    'remote refresh updates a clean record and preserves dirty form edits',
    () async {
      final raw = FakeDataSource(
        records: {
          'notes': {
            'one': BeakRecord.fromRow({'id': 'one', 'title': 'Before'}),
          },
        },
      );
      final source = ModelBeakDataSource(
        registry: BeakModelRegistry()..register(const NoteModel()),
        fallback: raw,
        refreshPolicy: const BeakRefreshPolicy(),
      );
      const title = BeakScalarField<String>(
        model: NoteModel(),
        column: BeakStringColumn(key: 'title', label: 'Title'),
      );
      final session = BeakFormSession(
        model: const NoteModel(),
        dataSource: source,
        recordId: 'one',
        layout: BeakFormLayout(children: [title.inputText()]),
      );
      await session.load();
      await raw.update('notes', 'one', BeakRecord.fromRow({'title': 'Remote'}));
      source.setForeground(false);
      source.setForeground(true);
      await pumpEventQueue();
      expect(session.root.read(title), 'Remote');
      session.root.set(title, 'Local edit');
      await raw.update(
        'notes',
        'one',
        BeakRecord.fromRow({'title': 'Another remote edit'}),
      );
      source.setForeground(false);
      source.setForeground(true);
      await pumpEventQueue();
      expect(session.root.read(title), 'Local edit');
      expect(session.root.isDirty, isTrue);
      session.dispose();
      await source.dispose();
    },
  );
}

class _ControlledTimer implements Timer {
  _ControlledTimer(this.callback);
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  void fire() {
    if (isActive) {
      tick++;
      callback(this);
    }
  }

  @override
  void cancel() => isActive = false;
}
