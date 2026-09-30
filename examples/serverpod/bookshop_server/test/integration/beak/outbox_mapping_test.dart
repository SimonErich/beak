import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';
import 'support/zone_bound_adapter.dart';

/// What `serverpod create-migration` writes for the `BeakOutboxEffect` model
/// documented on `beakServerpodFrameworkTables`: `String` is `text NOT NULL`,
/// `int` is `bigint NOT NULL`, and Serverpod adds the serial `id`.
const String _outboxDdl = '''
CREATE TABLE "beak_outbox" (
  "id" bigserial PRIMARY KEY,
  "effectKey" text NOT NULL,
  "effectKind" text NOT NULL,
  "payloadJson" text NOT NULL,
  "deliveryStatus" text NOT NULL,
  "attemptCount" bigint NOT NULL,
  "availableAt" bigint NOT NULL,
  "leaseToken" text NOT NULL,
  "lastError" text NOT NULL
)''';

/// The outbox mapping of `beakServerpodFrameworkTables`, on Serverpod's own
/// database: a row is enqueued, delivered once, marked delivered and pruned.
void main() {
  withServerpod(
    'Given the outbox model mapped onto a Serverpod table',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, endpoints) {
      final table = beakServerpodFrameworkTables.outbox;
      late ZoneBoundAdapter adapter;

      setUp(() async {
        adapter = ZoneBoundAdapter(
          sessionBuilder.build(),
          ServerpodSessionAdapter(),
        );
        await adapter.rawExecute('DROP TABLE IF EXISTS beak_outbox', const []);
        await adapter.rawExecute(_outboxDdl, const []);
      });

      tearDown(() => adapter.rawExecute('DROP TABLE beak_outbox', const []));

      test('an effect is enqueued once and delivered once', () async {
        final delivered = <BeakOutboxEffect>[];
        Future<void> enqueue() => adapter.transaction(
          (transaction) => BeakOutbox.enqueue(
            transaction,
            key: 'receipt-1',
            kind: 'receipt',
            payload: const BeakRecord(
              values: {'to': BeakStringValue('ada@example.com')},
            ),
            table: table,
          ),
        );
        await enqueue();
        await enqueue();

        final worker = BeakOutboxWorker(
          adapter: adapter,
          table: table,
          handlers: {'receipt': (effect) async => delivered.add(effect)},
        );

        expect(await worker.drain(), 1);
        expect(await worker.drain(), 0);
        expect(delivered.single.key, 'receipt-1');
        expect(delivered.single.payload['to']?.raw, 'ada@example.com');
        final rows = await adapter.rawQuery(
          'SELECT "deliveryStatus", "attemptCount" FROM beak_outbox',
          const [],
        );
        expect(rows.single['deliveryStatus'], 'delivered');
        expect(rows.single['attemptCount'], 1);
      });

      test(
        'a delivered effect is pruned by age, and a pending one is not',
        () async {
          Future<void> enqueue(String key) => adapter.transaction(
            (transaction) => BeakOutbox.enqueue(
              transaction,
              key: key,
              kind: 'receipt',
              payload: BeakRecord(values: {'key': BeakStringValue(key)}),
              table: table,
            ),
          );
          await enqueue('done');
          await enqueue('waiting');
          await BeakOutboxWorker(
            adapter: adapter,
            table: table,
            handlers: {
              'receipt': (effect) async {
                if (effect.key == 'waiting') throw StateError('provider down');
              },
            },
            retryDelay: const Duration(hours: 1),
          ).drain();

          final removed = await BeakOutbox.prune(
            adapter,
            olderThan: Duration.zero,
            table: table,
            now: () => DateTime.now().add(const Duration(days: 1)),
          );

          expect(removed, 1);
          final left = await adapter.rawQuery(
            'SELECT "effectKey" FROM beak_outbox',
            const [],
          );
          expect(left.single['effectKey'], 'waiting');
        },
      );
    },
  );
}
