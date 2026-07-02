/// Strict-mode full-table-scan guard on `QueryBuilder` read terminals and the
/// `Worm.unsafe` bypass, plus the destructive-vs-read flag split.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/exception/dangerous_query_exception.dart';
import 'package:worm/src/exception/full_table_scan_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/registry/worm.dart';

import '_fixtures.dart';

void main() {
  tearDown(Worm.reset);

  group('preventFullTableScans gate on .get()', () {
    test('strict mode throws on .get() with no .where()', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).get(),
        throwsA(isA<FullTableScanException>()),
      );
    });

    test('DangerousQueryException is the same type as the throw', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).get(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('non-strict mode allows .get() without .where()', () async {
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final users = await QueryBuilder<TestUser>.from(ctx).get();
      expect(users, isNotEmpty);
    });

    test('strict mode allows .get() with a .where()', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final users = await QueryBuilder<TestUser>.from(
        ctx,
      ).where(const Field<int>('age').eq(30)).get();
      expect(users, isNotEmpty);
    });

    test('Worm.unsafe wraps a blocked .get() and succeeds', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final users = await Worm.unsafe<List<TestUser>>(
        () => QueryBuilder<TestUser>.from(ctx).get(),
      );
      expect(users, hasLength(4));
      // Outside unsafe, the gate is reinstated.
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).get(),
        throwsA(isA<FullTableScanException>()),
      );
    });
  });

  group('preventDestructiveWithoutWhere unification', () {
    test('preventFullTableScans alone blocks unscoped delete', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).delete(),
        throwsA(isA<FullTableScanException>()),
      );
    });

    test(
      'preventDestructiveWithoutWhere blocks delete but allows read',
      () async {
        await Worm.initialize(
          config: const WormConfig(
            strictness: StrictnessConfig(preventDestructiveWithoutWhere: true),
          ),
          adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
        );
        final adapter = await seededAdapter();
        final ctx = userContext(adapter);
        await expectLater(
          QueryBuilder<TestUser>.from(ctx).delete(),
          throwsA(isA<FullTableScanException>()),
        );
        // Reads are unaffected when only the destructive flag is set.
        final users = await QueryBuilder<TestUser>.from(ctx).get();
        expect(users, isNotEmpty);
      },
    );

    test('Worm.unsafe bypasses destructive guard too', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(preventFullTableScans: true),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final deleted = await Worm.unsafe<int>(
        () => QueryBuilder<TestUser>.from(ctx).delete(),
      );
      expect(deleted, 4);
    });
  });

  group('preventFullTableScans gate on other read terminals', () {
    Future<void> initStrict() => Worm.initialize(
      config: const WormConfig(
        strictness: StrictnessConfig(preventFullTableScans: true),
      ),
      adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
    );

    test('strict mode throws on .first() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).first(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode throws on .count() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).count(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode throws on .exists() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).exists(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode throws on .pluck() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).pluck(const Field<int>('age')),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode throws on .paginate() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).paginate(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('strict mode throws on .cursorPaginate() with no .where()', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      await expectLater(
        QueryBuilder<TestUser>.from(ctx).cursorPaginate(),
        throwsA(isA<DangerousQueryException>()),
      );
    });

    test('.find() is exempt — succeeds in strict mode', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final user = await QueryBuilder<TestUser>.from(ctx).find(1);
      expect(user?.userId, 1);
    });

    test('DangerousQueryException carries the table name', () async {
      await initStrict();
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      try {
        await QueryBuilder<TestUser>.from(ctx).get();
        fail('expected DangerousQueryException');
      } on DangerousQueryException catch (e) {
        expect(e.table, 'users');
      }
    });
  });
}
