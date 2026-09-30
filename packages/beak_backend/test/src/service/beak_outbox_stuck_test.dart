import 'dart:async';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  late InMemoryAdapter adapter;
  final now = DateTime.utc(2026, 9, 28);

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await const BeakOutboxMigration().up(adapter);
    await BeakOutbox.enqueue(
      adapter,
      key: 'order:1:email',
      kind: 'email',
      payload: BeakRecord.fromRow({'amount': 100}),
    );
  });
  tearDown(() => adapter.close());

  Future<Map<String, Object?>> row() async => (await adapter.select(
    const QueryDescriptor(table: BeakOutboxMigration.table),
  )).single;

  test(
    'a handler that never returns is given up on when its lease ends',
    () async {
      // Without this the one hung provider call holds the worker forever: the
      // drain never returns, no later effect is delivered, and stopping the
      // loop never completes.
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        leaseDuration: const Duration(milliseconds: 50),
        handlers: {'email': (_) => Completer<void>().future},
      );

      expect(await worker.drain().timeout(const Duration(seconds: 5)), 0);

      final stored = await row();
      expect(stored['status'], 'pending');
      expect(stored['attempt'], 1);
      expect(stored['last_error'], 'timeout');
    },
  );

  test('a hung handler ends as failed once its attempts are used', () async {
    var calls = 0;
    var clock = now;
    final worker = BeakOutboxWorker(
      adapter: adapter,
      now: () => clock,
      leaseDuration: const Duration(milliseconds: 20),
      maxAttempts: 2,
      handlers: {
        'email': (_) {
          calls += 1;
          return Completer<void>().future;
        },
      },
    );
    await worker.drain().timeout(const Duration(seconds: 5));
    clock = clock.add(const Duration(hours: 1));
    await worker.drain().timeout(const Duration(seconds: 5));
    expect(calls, 2);
    expect((await row())['status'], 'failed');
  });

  test(
    'a claim that never reported after the last attempt is failed, not run again',
    () async {
      // The process died (or hung) inside the final attempt, so nothing ever
      // wrote the outcome. Running it a ninth time would make a poison message
      // crash the worker for ever.
      await adapter.update(
        const UpdateDescriptor(
          table: BeakOutboxMigration.table,
          values: {
            'status': 'running',
            'lease': 'lost-worker',
            'attempt': 2,
            'available_at': 0,
          },
        ),
      );
      var calls = 0;
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        maxAttempts: 2,
        handlers: {'email': (_) async => calls += 1},
      );

      expect(await worker.drain(), 0);
      expect(calls, 0);
      final stored = await row();
      expect(stored['status'], 'failed');
      expect(stored['last_error'], 'leaseExpired');
      expect(await worker.drain(), 0);
      expect(calls, 0);
    },
  );

  test('a lost claim with attempts left is still delivered', () async {
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
    var calls = 0;
    final worker = BeakOutboxWorker(
      adapter: adapter,
      now: () => now,
      maxAttempts: 2,
      handlers: {'email': (_) async => calls += 1},
    );
    expect(await worker.drain(), 1);
    expect(calls, 1);
  });
}
