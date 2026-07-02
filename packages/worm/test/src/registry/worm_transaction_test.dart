/// Worm.transaction commit/rollback, routing, nesting, afterCommit.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/registry/worm.dart';

import '../model/_fixtures.dart';

void main() {
  late InMemoryAdapter adapter;

  Future<int> rowCount() async =>
      (await adapter.select(const QueryDescriptor(table: 'tests'))).length;

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

  group('Worm.transaction', () {
    test('commits and returns the callback value', () async {
      final value = await Worm.transaction((txn) async {
        await (TestModel(tableNameOverride: 'tests')
              ..setAttribute('id', 1)
              ..setAttribute('name', 'Alice'))
            .save();
        return 'done';
      });
      expect(value, 'done');
      expect(await rowCount(), 1);
    });

    test('rolls back on throw and rethrows', () async {
      await expectLater(
        Worm.transaction((txn) async {
          await (TestModel(tableNameOverride: 'tests')
                ..setAttribute('id', 1)
                ..setAttribute('name', 'Alice'))
              .save();
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await rowCount(), 0);
    });

    test('ambient save routes through the transaction adapter', () async {
      // The save uses no explicit transaction; it must still enlist in
      // the ambient transaction (proven by the rollback undoing it).
      await expectLater(
        Worm.transaction((txn) async {
          final model = TestModel(tableNameOverride: 'tests')
            ..setAttribute('id', 1);
          await model.save();
          expect(await rowCount(), 1);
          throw StateError('rollback');
        }),
        throwsA(isA<StateError>()),
      );
      expect(await rowCount(), 0);
    });

    test(
      'nested transaction joins; afterCommit fires once at the end',
      () async {
        var commits = 0;
        await Worm.transaction((outer) async {
          await Worm.transaction((inner) async {
            final model = TestModel(tableNameOverride: 'tests')
              ..setAttribute('id', 1)
              ..afterCommit(() => commits++);
            await model.save();
            // Deferred: not yet fired inside the (joined) transaction.
            expect(commits, 0);
          });
          expect(commits, 0);
        });
        expect(commits, 1);
      },
    );

    test('afterCommit is discarded when the transaction rolls back', () async {
      var fired = false;
      await expectLater(
        Worm.transaction((txn) async {
          (TestModel(
            tableNameOverride: 'tests',
          )..setAttribute('id', 1)).afterCommit(() => fired = true);
          await (TestModel(
            tableNameOverride: 'tests',
          )..setAttribute('id', 1)).save();
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(fired, isFalse);
    });

    test('savepoint rolls back its slice while the outer commits', () async {
      await Worm.transaction((txn) async {
        await (TestModel(tableNameOverride: 'tests')
              ..setAttribute('id', 1)
              ..setAttribute('name', 'A'))
            .save();
        try {
          await txn.savepoint(() async {
            await (TestModel(tableNameOverride: 'tests')
                  ..setAttribute('id', 2)
                  ..setAttribute('name', 'B'))
                .save();
            throw StateError('rollback savepoint');
          });
        } on StateError {
          // Savepoint rolled back; outer transaction continues.
        }
      });
      final rows = await adapter.select(const QueryDescriptor(table: 'tests'));
      expect(rows.map((r) => r['id']), <Object?>[1]);
    });
  });
}
