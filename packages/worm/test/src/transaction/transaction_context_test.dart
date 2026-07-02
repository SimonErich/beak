/// TransactionContext savepoint gating and afterCommit queue.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/transaction/transaction_context.dart';

void main() {
  group('TransactionContext.savepoint', () {
    test('throws UnsupportedOperationException when unsupported', () async {
      final adapter = InMemoryAdapter(
        capabilities: const AdapterCapabilities(supportsTransactions: true),
      );
      await adapter.connect();
      final context = TransactionContext(
        adapter: adapter,
        connectionName: 'default',
      );

      await expectLater(
        () => context.savepoint(() async => 1),
        throwsA(isA<UnsupportedOperationException>()),
      );
    });

    test('runs the body and returns its value when supported', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final context = TransactionContext(
        adapter: adapter,
        connectionName: 'default',
      );

      final result = await context.savepoint(() async => 42);
      expect(result, 42);
    });
  });

  group('TransactionContext afterCommit queue', () {
    test('drain fires queued callbacks in order then clears', () {
      final adapter = InMemoryAdapter();
      final context = TransactionContext(
        adapter: adapter,
        connectionName: 'default',
      );
      final fired = <int>[];
      context
        ..enqueueAfterCommit(() => fired.add(1))
        ..enqueueAfterCommit(() => fired.add(2))
        ..drainAfterCommit();
      expect(fired, <int>[1, 2]);

      // Draining again is a no-op — the queue was cleared.
      context.drainAfterCommit();
      expect(fired, <int>[1, 2]);
    });

    test('discard clears the queue without firing', () {
      final adapter = InMemoryAdapter();
      final context = TransactionContext(
        adapter: adapter,
        connectionName: 'default',
      );
      var fired = false;
      context
        ..enqueueAfterCommit(() => fired = true)
        ..discardAfterCommit()
        ..drainAfterCommit();
      expect(fired, isFalse);
    });
  });
}
