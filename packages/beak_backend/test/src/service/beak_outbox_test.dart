import 'dart:async';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  late InMemoryAdapter adapter;
  var now = DateTime.utc(2026, 9, 28);
  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await const BeakOutboxMigration().up(adapter);
    now = DateTime.utc(2026, 9, 28);
  });
  tearDown(() => adapter.close());
  Future<void> enqueue({String key = 'order:1:email', int amount = 100}) =>
      BeakOutbox.enqueue(
        adapter,
        key: key,
        kind: 'email',
        payload: BeakRecord.fromRow({'amount': amount}),
      );

  test(
    'outbox follows transaction rollback and rejects changed identity',
    () async {
      await expectLater(
        adapter.transaction((tx) async {
          await BeakOutbox.enqueue(
            tx,
            key: 'rolled-back',
            kind: 'email',
            payload: BeakRecord.fromRow({'id': 1}),
          );
          throw const BeakValidationException('Rejected');
        }),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        await adapter.select(
          const QueryDescriptor(table: BeakOutboxMigration.table),
        ),
        isEmpty,
      );
      await enqueue();
      await enqueue();
      expect(
        await adapter.count(
          const AggregateDescriptor.count(table: BeakOutboxMigration.table),
        ),
        1,
      );
      await expectLater(
        enqueue(amount: 200),
        throwsA(isA<BeakConflictException>()),
      );
    },
  );

  test(
    'competing workers claim once and acknowledged effects never replay',
    () async {
      await enqueue();
      final started = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final handlers = <String, BeakEffectHandler>{
        'email': (effect) async {
          calls++;
          expect(effect.key, 'order:1:email');
          expect(effect.payload['amount']?.raw, 100);
          started.complete();
          await release.future;
        },
      };
      final first = BeakOutboxWorker(
        adapter: adapter,
        handlers: handlers,
        now: () => now,
      );
      final second = BeakOutboxWorker(
        adapter: adapter,
        handlers: handlers,
        now: () => now,
      );
      final pending = first.drain();
      await started.future;
      expect(await first.drain(), 0);
      expect(await second.drain(), 0);
      release.complete();
      expect(await pending, 1);
      expect(await second.drain(), 0);
      expect(calls, 1);
    },
  );

  test(
    'retries persist and stop at configured limit without leaking errors',
    () async {
      await enqueue();
      var calls = 0;
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        maxAttempts: 2,
        handlers: {
          'email': (_) async {
            calls++;
            throw StateError('secret provider credential');
          },
        },
      );
      expect(await worker.drain(), 0);
      expect(await worker.drain(), 0);
      now = now.add(const Duration(seconds: 10));
      expect(await worker.drain(), 0);
      now = now.add(const Duration(hours: 1));
      expect(await worker.drain(), 0);
      expect(calls, 2);
      final row = (await adapter.select(
        const QueryDescriptor(table: BeakOutboxMigration.table),
      )).single;
      expect(row['status'], 'failed');
      expect(row['last_error'], 'providerFailure');
    },
  );

  test('expired lease recovers stable identity after worker failure', () async {
    await enqueue();
    await adapter.update(
      const UpdateDescriptor(
        table: BeakOutboxMigration.table,
        values: {
          'status': 'running',
          'lease': 'lost-worker',
          'attempt': 1,
          'available_at': 0,
        },
      ),
    );
    final seen = <String>[];
    final worker = BeakOutboxWorker(
      adapter: adapter,
      now: () => now,
      handlers: {
        'email': (effect) async {
          seen.add(effect.key);
          expect(effect.attempt, 2);
        },
      },
    );
    expect(await worker.drain(), 1);
    expect(seen, ['order:1:email']);
  });
}
