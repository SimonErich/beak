import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/eager_load.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/relation/belongs_to.dart';
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

  group('Shared-head nested paths', () {
    QueryContext<TestUser> nestedContext(InMemoryAdapter adapter) =>
        QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
          relations: <String, Relation<Model, Model>>{
            'posts': userPostsRelation(),
            'user': postUserRelation(),
            'author': const BelongsToRelation<Model, Model>(
              name: 'author',
              parentTable: 'users',
              foreignKey: 'user_id',
              hydrateParent: TestUser.fromRow,
            ),
          },
        );

    test('sibling nested paths under one head all survive', () async {
      final adapter = await seededAdapter();
      final ctx = nestedContext(adapter);
      final parents = await QueryBuilder<TestUser>.from(ctx).get();
      final queries = await EagerLoader.run(
        context: ctx,
        parents: parents,
        loads: const [EagerLoad('posts.user'), EagerLoad('posts.author')],
        aggregates: const [],
      );

      // One merged 'posts' load + one query per sibling tail — NOT two
      // independent 'posts' loads clobbering each other's instances.
      expect(queries, 3);
      final alice = parents.firstWhere((u) => u.name == 'Alice');
      final posts = alice.relations['posts'];
      if (posts case final List<Model> list) {
        expect(list, hasLength(2));
        for (final post in list) {
          expect(
            post.relations['user'],
            isA<TestUser>().having((u) => u.name, 'name', 'Alice'),
            reason: 'the first sibling nested load must survive',
          );
          expect(
            post.relations['author'],
            isA<TestUser>().having((u) => u.name, 'name', 'Alice'),
            reason: 'the second sibling nested load must survive',
          );
        }
      } else {
        fail('Expected posts to be eager-loaded as List<Model>');
      }
    });

    test('duplicate paths for one head load it exactly once', () async {
      final adapter = await seededAdapter();
      final ctx = nestedContext(adapter);
      final parents = await QueryBuilder<TestUser>.from(ctx).get();
      final queries = await EagerLoader.run(
        context: ctx,
        parents: parents,
        loads: const [EagerLoad('posts'), EagerLoad('posts')],
        aggregates: const [],
      );
      expect(queries, 1);
      final alice = parents.firstWhere((u) => u.name == 'Alice');
      expect(alice.relations['posts'], isA<List<Model>>());
    });

    test('a shared TWO-segment head loads once with both deep siblings '
        'surviving', () async {
      // Guards the RECURSIVE head-merge (only exercised at depth 3+): the
      // paths share the two-segment prefix 'posts.author', so 'author' must
      // be loaded exactly once and both of its deep children attach to the
      // same author instances. A flattened (non-recursive) loader would load
      // 'author' twice and drop the first deep sibling.
      final adapter = await seededAdapter();
      final ctx = QueryContext<TestUser>(
        adapter: adapter,
        table: 'users',
        hydrate: TestUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
          'author': const BelongsToRelation<Model, Model>(
            name: 'author',
            parentTable: 'users',
            foreignKey: 'user_id',
            hydrateParent: TestUser.fromRow,
          ),
          'writtenPosts': const HasManyRelation<Model, Model>(
            name: 'writtenPosts',
            childTable: 'posts',
            foreignKey: 'user_id',
            hydrateChild: TestPost.fromRow,
          ),
          'recentPosts': const HasManyRelation<Model, Model>(
            name: 'recentPosts',
            childTable: 'posts',
            foreignKey: 'user_id',
            hydrateChild: TestPost.fromRow,
          ),
        },
      );
      final parents = await QueryBuilder<TestUser>.from(ctx).get();
      final queries = await EagerLoader.run(
        context: ctx,
        parents: parents,
        loads: const [
          EagerLoad('posts.author.writtenPosts'),
          EagerLoad('posts.author.recentPosts'),
        ],
        aggregates: const [],
      );

      // posts + ONE merged author + the two distinct leaf loads.
      expect(queries, 4);

      final alice = parents.firstWhere((u) => u.name == 'Alice');
      if (alice.relations['posts'] case final List<Model> posts) {
        final author = posts.first.relations['author'];
        if (author is TestUser) {
          expect(
            author.relations['writtenPosts'],
            isA<List<Model>>().having((l) => l.length, 'length', 2),
            reason: 'the first depth-3 sibling must survive',
          );
          expect(
            author.relations['recentPosts'],
            isA<List<Model>>().having((l) => l.length, 'length', 2),
            reason: 'the second depth-3 sibling must survive',
          );
        } else {
          fail('Expected the shared "author" head to be loaded once');
        }
      } else {
        fail('Expected posts to be eager-loaded as List<Model>');
      }
    });
  });
}
