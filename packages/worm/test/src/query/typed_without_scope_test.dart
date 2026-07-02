/// `withoutGlobalScope<SoftDeleteScope>()` bypasses the
/// scope via reified generics, with no string lookup at
/// the call site.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/relation_base.dart';
import 'package:worm/src/scope/global_scope.dart';
import 'package:worm/src/scope/soft_delete_scope.dart';

import '_fixtures.dart';

Future<InMemoryAdapter> _seedAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'name': 'Alice',
          'age': 30,
          'deleted_at': null,
        },
        <String, Object?>{
          'id': 2,
          'name': 'Bob',
          'age': 25,
          'deleted_at': '2024-01-01',
        },
        <String, Object?>{
          'id': 3,
          'name': 'Carol',
          'age': 40,
          'deleted_at': null,
        },
      ],
    ),
  );
  return adapter;
}

QueryContext<TestUser> _ctxWithSoftDelete(InMemoryAdapter adapter) =>
    QueryContext<TestUser>(
      adapter: adapter,
      table: 'users',
      hydrate: TestUser.fromRow,
      globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<Model>()],
      relations: const <String, Relation<Model, Model>>{},
    );

void main() {
  group('QueryBuilder.withoutGlobalScope<X>()', () {
    test(
      'typed form bypasses SoftDeleteScope without a string lookup',
      () async {
        final adapter = await _seedAdapter();
        // Default: SoftDeleteScope filters out Bob.
        final live = await QueryBuilder<TestUser>.from(
          _ctxWithSoftDelete(adapter),
        ).get();
        expect(live.map((u) => u.name).toSet(), <String>{'Alice', 'Carol'});

        // Typed bypass via generic.
        final all = await QueryBuilder<TestUser>.from(
          _ctxWithSoftDelete(adapter),
        ).withoutGlobalScope<SoftDeleteScope<Model>>().get();
        expect(all.map((u) => u.name).toSet(), <String>{
          'Alice',
          'Bob',
          'Carol',
        });
      },
    );

    test('typed bypass is a no-op when scope is not registered', () async {
      final adapter = await _seedAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
      );
      final qb = QueryBuilder<TestUser>.from(ctx);
      final returned = qb.withoutGlobalScope<SoftDeleteScope<Model>>();
      // No registered scope → returns the same builder.
      expect(identical(qb, returned), isTrue);
      final all = await returned.get();
      expect(all, hasLength(3));
    });

    test('withTrashed() still bypasses the soft-delete scope', () async {
      final adapter = await _seedAdapter();
      final all = await QueryBuilder<TestUser>.from(
        _ctxWithSoftDelete(adapter),
      ).withTrashed().get();
      expect(all.map((u) => u.name).toSet(), <String>{'Alice', 'Bob', 'Carol'});
    });

    test(
      'withoutGlobalScopes() (plural) is unchanged and disables all scopes',
      () async {
        final adapter = await _seedAdapter();
        final all = await QueryBuilder<TestUser>.from(
          _ctxWithSoftDelete(adapter),
        ).withoutGlobalScopes().get();
        expect(all, hasLength(3));
      },
    );
  });
}
