import 'package:test/test.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/scope/global_scope.dart';
import 'package:worm/src/scope/local_scope.dart';
import 'package:worm/src/scope/soft_delete_scope.dart';

import '../query/_fixtures.dart';

/// Test global scope that filters by minimum age.
final class _MinAgeScope extends GlobalScope<Model> {
  const _MinAgeScope(this.minAge);
  final int minAge;
  @override
  String get name => 'min_age';
  @override
  QueryBuilder<Model> apply(QueryBuilder<Model> builder) =>
      builder.where(const ComparableField<int>('age').gte(18));
}

/// Test local scope: filter adults only.
final class _AdultScope extends LocalScope<TestUser> {
  const _AdultScope();
  @override
  QueryBuilder<TestUser> apply(QueryBuilder<TestUser> builder) =>
      builder.where(const ComparableField<int>('age').gte(18));
}

void main() {
  group('GlobalScope', () {
    test('auto-applies to every query', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[_MinAgeScope(18)],
      );
      final users = await QueryBuilder<TestUser>.from(ctx).get();
      expect(users.every((u) => u.age >= 18), isTrue);
    });

    test('withoutGlobalScope<X>() bypasses scope by type', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[_MinAgeScope(18)],
      );
      final filtered = await QueryBuilder<TestUser>.from(
        ctx,
      ).withoutGlobalScope<_MinAgeScope>().get();
      expect(filtered, hasLength(4));
    });

    test('withoutGlobalScopes bypasses every scope', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[
          _MinAgeScope(18),
          SoftDeleteScope<TestUser>(),
        ],
      );
      final all = await QueryBuilder<TestUser>.from(
        ctx,
      ).withoutGlobalScopes().get();
      expect(all, hasLength(4));
    });

    test('SoftDeleteScope excludes deleted; withTrashed includes', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<TestUser>()],
      );
      final live = await QueryBuilder<TestUser>.from(ctx).get();
      expect(live.map((u) => u.name), isNot(contains('Carol')));
      expect(live, hasLength(3));

      final withTrashed = await QueryBuilder<TestUser>.from(
        ctx,
      ).withTrashed().get();
      expect(withTrashed.map((u) => u.name), contains('Carol'));
      expect(withTrashed, hasLength(4));
    });
  });

  group('LocalScope', () {
    test('chains correctly via scope()', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
      );
      final adults = await QueryBuilder<TestUser>.from(
        ctx,
      ).scope(const _AdultScope()).get();
      expect(adults.every((u) => u.age >= 18), isTrue);
      expect(adults, hasLength(4));
    });

    test('composes with global scopes', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<TestUser>()],
      );
      final adults = await QueryBuilder<TestUser>.from(
        ctx,
      ).scope(const _AdultScope()).get();
      // SoftDelete excludes Carol; local scope keeps all live adults.
      expect(
        adults.map((u) => u.name),
        unorderedEquals(<String>['Alice', 'Bob', 'Dave']),
      );
    });
  });
}
