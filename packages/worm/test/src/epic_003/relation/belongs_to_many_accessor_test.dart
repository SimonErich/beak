/// Runtime behavior tests for [BelongsToManyAccessor]: attach,
/// detach, and sync (with [PivotSyncResult] inspection).
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../_fixtures.dart';

const BelongsToManyRelation<TUser, TRole> _rolesRelation =
    BelongsToManyRelation<TUser, TRole>(
      name: 'roles',
      relatedTable: 'roles',
      pivotTable: 'role_user',
      parentPivotKey: 'user_id',
      relatedPivotKey: 'role_id',
      hydrateRelated: TRole.fromRow,
    );

Future<List<int>> _pivotRoleIdsFor(InMemoryAdapter adapter, int userId) async {
  const field = Field<Object?>('user_id');
  final rows = await adapter.select(
    QueryDescriptor(table: 'role_user', where: field.eq(userId)),
  );
  return <int>[
    for (final row in rows)
      if (row['role_id'] case final int id) id,
  ]..sort();
}

void main() {
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'roles'),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(table: 'role_user'),
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, InMemoryAdapter>{'default': adapter},
    );
  });

  tearDown(Worm.reset);

  group('BelongsToManyAccessor', () {
    test('attach(5) inserts exactly one pivot row for relatedId=5', () async {
      final user = TUser(userId: 1, name: 'Ada');
      await user.save();
      final accessor = BelongsToManyAccessor<TUser, TRole>(
        parent: user,
        relation: _rolesRelation,
      );

      await accessor.attach(5);

      final ids = await _pivotRoleIdsFor(adapter, 1);
      expect(ids, <int>[5]);
    });

    test(
      'detach(1) removes the pivot row and returns the deleted count',
      () async {
        final user = TUser(userId: 2, name: 'Grace');
        await user.save();
        final accessor = BelongsToManyAccessor<TUser, TRole>(
          parent: user,
          relation: _rolesRelation,
        );
        await accessor.attachAll(<Object>[1, 2]);

        final removed = await accessor.detach(1);

        expect(removed, 1);
        final ids = await _pivotRoleIdsFor(adapter, 2);
        expect(ids, <int>[2]);
      },
    );

    test('sync([1,2,3]) over existing [1,2,4] yields pivot [1,2,3] and '
        'PivotSyncResult(attached=[3], detached=[4])', () async {
      final user = TUser(userId: 3, name: 'Hedy');
      await user.save();
      final accessor = BelongsToManyAccessor<TUser, TRole>(
        parent: user,
        relation: _rolesRelation,
      );
      await accessor.attachAll(<Object>[1, 2, 4]);

      final result = await accessor.sync(<Object>[1, 2, 3]);

      expect(result, isA<PivotSyncResult>());
      expect(result.attached, <Object>[3]);
      expect(result.detached, <Object>[4]);

      final ids = await _pivotRoleIdsFor(adapter, 3);
      expect(ids, <int>[1, 2, 3]);
    });

    test('sync removes pivot rows for ids no longer requested', () async {
      final user = TUser(userId: 4, name: 'Margaret');
      await user.save();
      final accessor = BelongsToManyAccessor<TUser, TRole>(
        parent: user,
        relation: _rolesRelation,
      );
      await accessor.attachAll(<Object>[10, 11, 12]);

      await accessor.sync(<Object>[10]);

      final ids = await _pivotRoleIdsFor(adapter, 4);
      expect(ids, <int>[10]);
    });
  });
}
