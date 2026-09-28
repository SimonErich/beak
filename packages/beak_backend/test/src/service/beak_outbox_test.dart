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

  Future<void> insertCorruptRow() => adapter.insert(
    const InsertDescriptor(
      table: BeakOutboxMigration.table,
      values: {
        'id': 'broken',
        'kind': 'email',
        'payload': '{}',
        'status': 'pending',
        'attempt': 0,
        'available_at': 0,
        'lease': null,
        'last_error': '',
      },
    ),
  );

  Future<Map<String, Object?>?> stored(String id) => adapter.selectOne(
    QueryDescriptor(
      table: BeakOutboxMigration.table,
      where: const StringField('id').eq(id),
    ),
  );

  group('malformed rows', () {
    test('a malformed row is set aside and reported, never claimed', () async {
      // Only BeakOutbox.enqueue writes this table, so a row without a lease
      // is corruption. Claiming it blindly could double-deliver; letting it
      // abort the drain would starve every effect queued behind it.
      await insertCorruptRow();
      await enqueue();
      final delivered = <String>[];
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      );

      await expectLater(
        worker.drain(),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('"broken"'),
          ),
        ),
      );
      expect(delivered, ['order:1:email']);
      final broken = await stored('broken');
      expect(broken?['status'], 'failed');
      expect(broken?['last_error'], 'malformedRow');
      expect(broken?['lease'], isNull, reason: 'the row was never claimed');
      expect(
        await worker.drain(),
        0,
        reason: 'a set-aside row is reported once, not on every drain',
      );
    });

    test('a row without a usable id is skipped on every drain', () async {
      // Nothing can address it, so it cannot be set aside; it is reported
      // each time, and still blocks nothing.
      await adapter.insert(
        const InsertDescriptor(
          table: BeakOutboxMigration.table,
          values: {
            'id': 42,
            'kind': 'email',
            'payload': '{}',
            'status': 'pending',
            'attempt': 0,
            'available_at': 0,
            'lease': '',
            'last_error': '',
          },
        ),
      );
      await enqueue();
      final delivered = <String>[];
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      );
      final reportsTheRow = throwsA(
        isA<BeakConfigurationException>().having(
          (e) => e.message,
          'message',
          contains('"42"'),
        ),
      );

      await expectLater(worker.drain(), reportsTheRow);
      await expectLater(worker.drain(), reportsTheRow);
      expect(delivered, ['order:1:email']);
    });

    test(
      'an effect nobody handles is retried like a failed delivery',
      () async {
        await enqueue(key: 'unhandled');
        final worker = BeakOutboxWorker(
          adapter: adapter,
          now: () => now,
          handlers: const {},
          maxAttempts: 1,
        );

        expect(await worker.drain(), 0);
        final unhandled = await stored('unhandled');
        expect(unhandled?['status'], 'failed');
        expect(unhandled?['last_error'], 'configuration');
      },
    );

    test('an undecodable payload fails that effect, not the queue', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: BeakOutboxMigration.table,
          values: {
            'id': 'bad-payload',
            'kind': 'email',
            'payload': '[1, 2]',
            'status': 'pending',
            'attempt': 0,
            'available_at': 0,
            'lease': '',
            'last_error': '',
          },
        ),
      );
      await enqueue();
      final delivered = <String>[];
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      );

      expect(await worker.drain(), 1);
      expect(delivered, ['order:1:email']);
      final broken = await adapter.selectOne(
        QueryDescriptor(
          table: BeakOutboxMigration.table,
          where: const StringField('id').eq('bad-payload'),
        ),
      );
      expect(broken?['status'], 'pending');
      expect(broken?['last_error'], 'configuration');
    });
  });

  group('BeakOutboxSchedule', () {
    Future<void> until(bool Function() condition) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('condition not met within 5 seconds');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('drains on its interval until stopped', () async {
      final delivered = <String>[];
      final loop = BeakOutboxSchedule(
        interval: const Duration(milliseconds: 10),
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      ).start(adapter, onError: (error, stackTrace) => fail('$error'));
      addTearDown(loop.stop);
      expect(loop.isRunning, isTrue);

      await enqueue(key: 'first');
      await until(() => delivered.contains('first'));
      await loop.stop();
      expect(loop.isRunning, isFalse);
      await enqueue(key: 'after-stop');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(delivered, ['first'], reason: 'a stopped loop drains nothing');
    });

    test('stop waits for the drain in flight', () async {
      final release = Completer<void>();
      final started = Completer<void>();
      var finished = false;
      final loop = BeakOutboxSchedule(
        interval: const Duration(milliseconds: 5),
        handlers: {
          'email': (effect) async {
            started.complete();
            await release.future;
            finished = true;
          },
        },
      ).start(adapter, onError: (error, stackTrace) => fail('$error'));
      await enqueue();
      await started.future;

      final stopping = loop.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(finished, isFalse);
      release.complete();
      await stopping;

      expect(finished, isTrue, reason: 'nothing is left half-delivered');
    });

    test('reports a failing drain and keeps its schedule', () async {
      await insertCorruptRow();
      final errors = <Object>[];
      final delivered = <String>[];
      final loop = BeakOutboxSchedule(
        interval: const Duration(milliseconds: 5),
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      ).start(adapter, onError: (error, stackTrace) => errors.add(error));
      addTearDown(loop.stop);

      await until(() => errors.isNotEmpty);
      await enqueue(key: 'after-the-failure');
      await until(() => delivered.contains('after-the-failure'));

      expect(errors, [isA<BeakConfigurationException>()]);
      expect(loop.isRunning, isTrue);
    });

    test('its worker carries the configured retry policy and clock', () async {
      await enqueue();
      var calls = 0;
      final worker = BeakOutboxSchedule(
        maxAttempts: 1,
        retryDelay: Duration.zero,
        leaseDuration: const Duration(seconds: 1),
        handlers: {
          'email': (_) async {
            calls++;
            throw StateError('down');
          },
        },
      ).worker(adapter, now: () => now);

      expect(await worker.drain(), 0);
      expect(await worker.drain(), 0);
      expect(calls, 1, reason: 'maxAttempts reached the worker');
      expect(worker.leaseDuration, const Duration(seconds: 1));
      expect(worker.retryDelay, Duration.zero);
    });

    test('validate accepts a schedule the loop can run', () {
      expect(const BeakOutboxSchedule(handlers: {}).validate, returnsNormally);
    });

    test('validate rejects what start would refuse, without an adapter', () {
      for (final schedule in [
        const BeakOutboxSchedule(interval: Duration.zero, handlers: {}),
        const BeakOutboxSchedule(drainLimit: 0, handlers: {}),
        const BeakOutboxSchedule(drainLimit: 1001, handlers: {}),
        const BeakOutboxSchedule(maxAttempts: 0, handlers: {}),
        const BeakOutboxSchedule(leaseDuration: Duration.zero, handlers: {}),
        const BeakOutboxSchedule(
          retryDelay: Duration(seconds: -1),
          handlers: {},
        ),
      ]) {
        expect(schedule.validate, throwsA(isA<BeakConfigurationException>()));
      }
    });

    test('rejects an interval that would never tick', () {
      expect(
        () => const BeakOutboxSchedule(
          interval: Duration.zero,
          handlers: {},
        ).start(adapter, onError: (error, stackTrace) {}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a drain limit the worker would refuse', () {
      for (final drainLimit in [0, 1001]) {
        expect(
          () => BeakOutboxSchedule(
            drainLimit: drainLimit,
            handlers: const {},
          ).start(adapter, onError: (error, stackTrace) {}),
          throwsA(isA<BeakConfigurationException>()),
          reason: '$drainLimit',
        );
      }
    });
  });
}
