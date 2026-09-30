import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// The claim scan against a real SQL dialect. The in-memory adapter walks the
/// predicate tree, so it cannot show what a compiler does with `OR` inside
/// `AND`: without explicit grouping every pending entry is due on every scan.
void main() {
  late SqliteAdapter adapter;
  var now = DateTime.utc(2026, 9, 28);

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    await const BeakOutboxMigration().up(adapter);
    now = DateTime.utc(2026, 9, 28);
  });
  tearDown(() => adapter.disconnect());

  test(
    'a failed effect waits out its backoff before the next attempt',
    () async {
      await BeakOutbox.enqueue(
        adapter,
        key: 'order:1:email',
        kind: 'email',
        payload: BeakRecord.fromRow({'amount': 100}),
      );
      var calls = 0;
      final worker = BeakOutboxWorker(
        adapter: adapter,
        now: () => now,
        maxAttempts: 3,
        handlers: {
          'email': (_) async {
            calls++;
            throw StateError('provider down');
          },
        },
      );

      await worker.drain();
      expect(calls, 1);

      await worker.drain();
      expect(calls, 1, reason: 'not due yet');

      now = now.add(const Duration(hours: 1));
      await worker.drain();
      expect(calls, 2);
    },
  );
}
