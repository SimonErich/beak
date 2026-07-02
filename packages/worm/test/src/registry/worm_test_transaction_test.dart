/// Tests for [Worm.beginTestTransaction] / [Worm.rollbackTestTransaction].
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/configuration_exception.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

Future<void> _initWorm(InMemoryAdapter adapter) async {
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, InMemoryAdapter>{'default': adapter},
  );
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'rows'),
    );
    await _initWorm(adapter);
  });

  tearDown(Worm.reset);

  group('beginTestTransaction + rollbackTestTransaction', () {
    test('rollback undoes inserts performed during the transaction', () async {
      final before = await adapter.select(const QueryDescriptor(table: 'rows'));
      expect(before, isEmpty);

      await Worm.beginTestTransaction();
      await Worm.adapter().insert(
        const InsertDescriptor(
          table: 'rows',
          values: <String, Object?>{'id': 1},
        ),
      );
      await Worm.rollbackTestTransaction();

      final after = await adapter.select(const QueryDescriptor(table: 'rows'));
      expect(after, hasLength(before.length));
    });

    test(
      'Worm.adapter() returns the transactional handle while active',
      () async {
        final rootBefore = Worm.adapter();
        await Worm.beginTestTransaction();
        final inTxn = Worm.adapter();
        expect(identical(inTxn, rootBefore), isFalse);
        await Worm.rollbackTestTransaction();
        expect(identical(Worm.adapter(), rootBefore), isTrue);
      },
    );
  });

  group('duplicate begin', () {
    test(
      'throws ConfigurationException with key test_transaction.duplicate',
      () async {
        await Worm.beginTestTransaction();
        await expectLater(
          Worm.beginTestTransaction,
          throwsA(
            predicate<Object?>(
              (e) =>
                  e is ConfigurationException &&
                  e.key == 'test_transaction.duplicate',
              'ConfigurationException with key "test_transaction.duplicate"',
            ),
          ),
        );
        await Worm.rollbackTestTransaction();
      },
    );
  });

  group('rollback when inactive', () {
    test('is a no-op (does not throw)', () async {
      await Worm.rollbackTestTransaction();
      await Worm.rollbackTestTransaction();
    });
  });

  group('Worm.reset() with an active test transaction', () {
    test('clears the transaction and leaves no dangling completer', () async {
      await Worm.beginTestTransaction();
      await Worm.adapter().insert(
        const InsertDescriptor(
          table: 'rows',
          values: <String, Object?>{'id': 9},
        ),
      );
      await Worm.reset();

      // After reset, Worm is uninitialized; re-initialize on a
      // fresh adapter and observe an empty table — proves no
      // pending callback survived.
      final fresh = InMemoryAdapter();
      await fresh.connect();
      await fresh.executeSchema(
        const SchemaDescriptor.createTable(table: 'rows'),
      );
      await _initWorm(fresh);

      // Beginning a new transaction immediately would block
      // forever if a stale completer was still suspended.
      await Worm.beginTestTransaction();
      await Worm.rollbackTestTransaction();
      final rows = await fresh.select(const QueryDescriptor(table: 'rows'));
      expect(rows, isEmpty);
    });
  });
}
