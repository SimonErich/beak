/// Runtime behaviour for codegen-style typed scope methods, auto-applied
/// global scopes, and the typed `withoutGlobalScope<X>()` escape hatch.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/scope/global_scope.dart';
import 'package:worm/src/scope/local_scope.dart';

import '../query/_fixtures.dart';

/// Stand-in for what `@LocalScope` codegen would emit at compile
/// time for a `PublishedScope` declared on a `Post`-like model.
final class _PublishedScope extends LocalScope<TestUser> {
  const _PublishedScope();

  @override
  QueryBuilder<TestUser> apply(QueryBuilder<TestUser> builder) =>
      builder.where(const ComparableField<int>('age').gte(30));
}

/// Stand-in for what `@GlobalScope` codegen would emit — auto-
/// applied to every `QueryBuilder<TestUser>` from the context.
final class _TenantScope extends GlobalScope<Model> {
  const _TenantScope();

  @override
  String get name => 'tenant';

  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const ComparableField<int>('age').gte(18));
}

/// Stricter scope used to prove `withoutGlobalScope<X>` actually
/// drops rows that the scope would have filtered out.
final class _AdultOnlyScope extends GlobalScope<Model> {
  const _AdultOnlyScope();

  @override
  String get name => 'adult-only';

  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const ComparableField<int>('age').gte(35));
}

/// A scope that is never registered on the context. Used to prove
/// the typed bypass is a no-op when the requested scope is absent.
final class _UnregisteredScope extends GlobalScope<Model> {
  const _UnregisteredScope();

  @override
  String get name => 'unregistered';

  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) => builder;
}

/// Mirrors the generator output: a typed extension method on
/// `QueryBuilder<TestUser>` for the `published` scope so spec
/// examples such as `User.query().published()` compile literally.
extension _TestUserScopeMethods on QueryBuilder<TestUser> {
  QueryBuilder<TestUser> published() => scope(const _PublishedScope());
}

void main() {
  group('typed scope methods', () {
    test(
      'query.published() adds the scope predicate to the where tree',
      () async {
        final adapter = await seededAdapter();
        final ctx = userContext(adapter);
        final rows = await QueryBuilder<TestUser>.from(ctx).published().get();
        expect(rows.every((u) => u.age >= 30), isTrue);
      },
    );

    test('extension method composes with further chainables', () async {
      final adapter = await seededAdapter();
      final ctx = userContext(adapter);
      final rows = await QueryBuilder<TestUser>.from(
        ctx,
      ).published().where(const Field<String>('name').eq('Alice')).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Alice');
    });
  });

  group('auto-application of @GlobalScope', () {
    test('every QueryBuilder<TestUser> picks up the scope', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[_TenantScope()],
      );
      final rows = await QueryBuilder<TestUser>.from(ctx).get();
      expect(rows.every((u) => u.age >= 18), isTrue);
      // Carol has age 40 but is soft-deleted; tenant scope keeps
      // her here because we did not register SoftDeleteScope.
      expect(rows, hasLength(4));
    });
  });

  group('withoutGlobalScope<X>() escape hatch', () {
    QueryBuilder<TestUser> adultOnlyBuilder(InMemoryAdapter adapter) =>
        QueryBuilder<TestUser>.from(
          QueryContext<TestUser>(
            adapter: adapter,
            table: 'users',
            hydrate: TestUser.fromRow,
            globalScopes: const <GlobalScope<Model>>[_AdultOnlyScope()],
          ),
        );

    test(
      'drops the named scope and lets previously filtered rows through',
      () async {
        final adapter = await seededAdapter();
        final scoped = adultOnlyBuilder(adapter);
        final filtered = await scoped.get();
        final bypassed = await scoped
            .withoutGlobalScope<_AdultOnlyScope>()
            .get();
        // Seed has Alice (30), Bob (25), Carol (40), Dave (35). AdultOnly
        // (age >= 35) keeps only Carol + Dave.
        expect(filtered.map((u) => u.userId).toSet(), <int>{3, 4});
        expect(bypassed, hasLength(4));
        expect(filtered.length, lessThan(bypassed.length));
      },
    );

    test(
      'returns an equivalent builder when the type is not registered',
      () async {
        final adapter = await seededAdapter();
        final scoped = adultOnlyBuilder(adapter);
        // _UnregisteredScope is not in globalScopes — must be a no-op.
        final bypassed = await scoped
            .withoutGlobalScope<_UnregisteredScope>()
            .get();
        final baseline = await scoped.get();
        expect(
          bypassed.map((u) => u.userId).toList(),
          baseline.map((u) => u.userId).toList(),
        );
      },
    );

    test('withoutGlobalScopes() disables every global scope', () async {
      final adapter = await seededAdapter();
      final scoped = adultOnlyBuilder(adapter);
      final bypassed = await scoped.withoutGlobalScopes().get();
      expect(bypassed, hasLength(4));
    });
  });
}
