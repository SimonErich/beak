import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/relation/eager_loader.dart';
import 'package:worm/src/relation/has_many.dart';
import 'package:worm/src/relation/relation_base.dart';

import '../query/_fixtures.dart';

void main() {
  group('Eager loading', () {
    test('single relation path runs exactly 1 query', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(
        ctx,
      ).withRelationPaths(<String>['posts']).get();
      expect(users, hasLength(4));
      final alice = users.firstWhere((u) => u.name == 'Alice');
      final posts = alice.relations['posts'];
      expect(posts, isA<List<Model>>());
      if (posts case final List<Model> list) {
        expect(list, hasLength(2));
      }
    });

    test('EagerLoader.run reports correct query count', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final parents = await QueryBuilder<TestUser>.from(ctx).get();
      final queries = await EagerLoader.run(
        context: ctx,
        parents: parents,
        loads: const [],
        aggregates: const [],
      );
      expect(queries, 0);
    });

    test('Eager loading on empty parents returns 0 queries', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final queries = await EagerLoader.run(
        context: ctx,
        parents: const <TestUser>[],
        loads: const [],
        aggregates: const [],
      );
      expect(queries, 0);
    });
  });

  group('HasMany relation', () {
    test('loads children grouped by parent id in a single query', () async {
      final adapter = await seededAdapter();
      const relation = HasManyRelation<Model, Model>(
        name: 'posts',
        childTable: 'posts',
        foreignKey: 'user_id',
        hydrateChild: TestPost.fromRow,
      );
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      final parents = <Model>[for (final row in rows) TestUser.fromRow(row)];
      final result = await relation.load(adapter, parents);
      expect(result.stats.queriesExecuted, 1);
      for (final p in parents) {
        result.setOnParent(p);
      }
      final alice = parents.whereType<TestUser>().firstWhere(
        (p) => p.name == 'Alice',
      );
      if (alice.relations['posts'] case final List<Model> list) {
        expect(list, hasLength(2));
      } else {
        fail('Expected List<Model>');
      }
    });
  });

  group('withCount / withSum / withExists aggregates', () {
    test('withCount populates injected count field', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(
        ctx,
      ).withCount('posts').get();
      final alice = users.firstWhere((u) => u.name == 'Alice');
      expect(alice.injectedFields['postsCount'], 2);
      final carol = users.firstWhere((u) => u.name == 'Carol');
      expect(carol.injectedFields['postsCount'], 0);
    });

    test('withExists populates injected boolean', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(
        ctx,
      ).withExists('posts').get();
      final alice = users.firstWhere((u) => u.name == 'Alice');
      expect(alice.injectedFields['postsExists'], true);
      final carol = users.firstWhere((u) => u.name == 'Carol');
      expect(carol.injectedFields['postsExists'], false);
    });

    test('withSum aggregates a numeric column', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(
        ctx,
      ).withSum('posts', 'views').get();
      final alice = users.firstWhere((u) => u.name == 'Alice');
      expect(alice.injectedFields['postsSum'], 300);
    });

    test('aggregate over non-HasMany/HasOne relation throws '
        'UnsupportedOperationException', () async {
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestPost>(
        adapter: adapter,
        table: 'posts',
        hydrate: TestPost.fromRow,
        relations: <String, Relation<Model, Model>>{'user': postUserRelation()},
      );
      await expectLater(
        QueryBuilder<TestPost>.from(ctx).withCount('user').get(),
        throwsA(
          isA<UnsupportedOperationException>().having(
            (e) => e.operation,
            'operation',
            'aggregate.userCount',
          ),
        ),
      );
    });
  });
}
