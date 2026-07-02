/// Constrained eager-loading and typed nested eager-load paths.
///
/// Exercises `QueryBuilder.withRelation` with a `PredicateTree`
/// constraint, `QueryBuilder.withNested` driven by
/// `RelationField.include`, the empty-children edge case
/// `RelationField.include(<>)`, and a direct invocation of
/// `EagerLoader.run` to assert the integer it returns.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../_fixtures.dart';

/// Generated companion stand-ins so the test reads exactly like
/// generator-produced code.
abstract final class _User$ {
  static const RelationField<TUser, TPost> posts = RelationField<TUser, TPost>(
    'posts',
    foreignKey: 'user_id',
  );
}

abstract final class _Post$ {
  static const RelationField<TPost, TComment> comments =
      RelationField<TPost, TComment>('comments', foreignKey: 'post_id');
  static const Field<bool> published = Field<bool>('published');
}

/// Counts adapter-recorded `SELECT` log entries.
int _selectCount(InMemoryQueryLogger logger) =>
    logger.entries.where((QueryLog e) => e.statement.contains('SELECT')).length;

QueryContext<TUser> _userContext(LoggingAdapter adapter) => QueryContext<TUser>(
  adapter: adapter,
  table: 'users',
  hydrate: TUser.fromRow,
  relations: <String, Relation<Model, Model>>{
    'posts': const HasManyRelation<Model, Model>(
      name: 'posts',
      childTable: 'posts',
      foreignKey: 'user_id',
      hydrateChild: TPost.fromRow,
    ),
    'comments': const HasManyRelation<Model, Model>(
      name: 'comments',
      childTable: 'comments',
      foreignKey: 'post_id',
      hydrateChild: TComment.fromRow,
    ),
  },
);

void main() {
  late InMemoryAdapter inner;
  late LoggingAdapter adapter;
  late InMemoryQueryLogger logger;

  setUp(() async {
    inner = InMemoryAdapter();
    await inner.connect();
    await inner.executeSchema(
      const SchemaDescriptor.createTable(table: 'users'),
    );
    await inner.executeSchema(
      const SchemaDescriptor.createTable(table: 'posts'),
    );
    await inner.executeSchema(
      const SchemaDescriptor.createTable(table: 'comments'),
    );
    await inner.insertMany(
      const InsertManyDescriptor(
        table: 'users',
        rows: <Map<String, Object?>>[
          <String, Object?>{'id': 1, 'name': 'Alice'},
          <String, Object?>{'id': 2, 'name': 'Bob'},
        ],
      ),
    );
    await inner.insertMany(
      const InsertManyDescriptor(
        table: 'posts',
        rows: <Map<String, Object?>>[
          <String, Object?>{
            'id': 10,
            'user_id': 1,
            'title': 'Published-A',
            'published': true,
          },
          <String, Object?>{
            'id': 11,
            'user_id': 1,
            'title': 'Draft-A',
            'published': false,
          },
          <String, Object?>{
            'id': 12,
            'user_id': 2,
            'title': 'Published-B',
            'published': true,
          },
        ],
      ),
    );
    await inner.insertMany(
      const InsertManyDescriptor(
        table: 'comments',
        rows: <Map<String, Object?>>[
          <String, Object?>{'id': 100, 'post_id': 10, 'body': 'first'},
          <String, Object?>{'id': 101, 'post_id': 10, 'body': 'second'},
          <String, Object?>{'id': 102, 'post_id': 12, 'body': 'third'},
        ],
      ),
    );
    logger = InMemoryQueryLogger();
    adapter = LoggingAdapter(
      inner: inner,
      logger: logger,
      strictness: const StrictnessConfig(),
      adapterName: 'InMemory',
    );
    await Worm.initialize(
      config: const WormConfig(),
      adapters: <String, LoggingAdapter>{'default': adapter},
    );
    logger.clear();
  });

  tearDown(Worm.reset);

  group('withRelation with PredicateTree constraint', () {
    test('withRelation(User\$.posts, Post\$.published.eq(true)) loads only '
        'published posts; unpublished posts are absent', () async {
      final users = await QueryBuilder<TUser>.from(
        _userContext(adapter),
      ).withRelation(_User$.posts, _Post$.published.eq(true)).get();

      final alice = users.firstWhere((u) => u.name == 'Alice');
      final loaded = alice.relations['posts'];
      expect(loaded, isA<List<Model>>());
      if (loaded case final List<Model> list) {
        // Only Alice's published post (id 10) loads — the draft
        // (id 11) is filtered out by the predicate.
        expect(list, hasLength(1));
        final single = list.single;
        expect(single, isA<TPost>());
        if (single is TPost) {
          expect(single.postId, 10);
          expect(single.published, isTrue);
        }
      }
    });

    test('unconstrained withRelation loads every child (no regression vs '
        'the previous unconstrained eager-load behavior)', () async {
      final users = await QueryBuilder<TUser>.from(
        _userContext(adapter),
      ).withRelation(_User$.posts).get();
      final alice = users.firstWhere((u) => u.name == 'Alice');
      final loaded = alice.relations['posts'];
      expect(loaded, isA<List<Model>>());
      if (loaded case final List<Model> list) {
        // Both published (10) and draft (11) load — passing `null`
        // (or omitting the constraint) is identical to the
        // unconstrained eager-load behavior.
        expect(list, hasLength(2));
        final ids = list.whereType<TPost>().map((p) => p.postId).toSet();
        expect(ids, <int>{10, 11});
      }
    });
  });

  group('withNested: typed nested eager-load', () {
    test(
      'withNested(User\$.posts.include([Post\$.comments])) yields the '
      'right total query count and populates relations["comments"]',
      () async {
        logger.clear();
        final users = await QueryBuilder<TUser>.from(_userContext(adapter))
            .withNested(
              _User$.posts.include(<RelationField<Model, Model>>[
                _Post$.comments,
              ]),
            )
            .get();

        // Total SELECTs: parent users + posts + comments = 3.
        expect(_selectCount(logger), 3);
        expect(users, hasLength(2));

        final alice = users.firstWhere((u) => u.name == 'Alice');
        final posts = alice.relations['posts'];
        expect(posts, isA<List<Model>>());
        if (posts case final List<Model> list) {
          expect(list, hasLength(2));
          final postA = list.whereType<TPost>().firstWhere(
            (p) => p.postId == 10,
          );
          final comments = postA.relations['comments'];
          expect(comments, isA<List<Model>>());
          if (comments case final List<Model> commentList) {
            expect(commentList, hasLength(2));
            final bodies = commentList
                .whereType<TComment>()
                .map((c) => c.body)
                .toSet();
            expect(bodies, <String>{'first', 'second'});
          }
        }
      },
    );

    test('EagerLoader.run returns the eager-load query count for a 2-level '
        'nested path (posts + comments = 2); the third query is the '
        'caller-issued parent SELECT', () async {
      // Parents already loaded — EagerLoader.run only executes the
      // eager-load queries, not the parent query.
      final parents = <TUser>[
        TUser.fromRow(<String, Object?>{'id': 1, 'name': 'Alice'}),
        TUser.fromRow(<String, Object?>{'id': 2, 'name': 'Bob'}),
      ];
      logger.clear();
      final eagerQueries = await EagerLoader.run<TUser>(
        context: _userContext(adapter),
        parents: parents,
        loads: const <EagerLoad>[EagerLoad('posts.comments')],
        aggregates: const <AggregateInjection>[],
      );

      // Two SELECTs from inside EagerLoader.run: posts + comments.
      expect(eagerQueries, 2);
      expect(_selectCount(logger), 2);

      // Adding the parent SELECT the caller would normally have
      // issued before EagerLoader.run gets the AC-stated total of
      // exactly 3 queries for 1 parent + 1 posts + 1 comments.
      expect(eagerQueries + 1, 3);

      // Eager-loaded data is wired onto the parents.
      final alice = parents.firstWhere((u) => u.name == 'Alice');
      final posts = alice.relations['posts'];
      if (posts case final List<Model> list) {
        final postA = list.whereType<TPost>().firstWhere((p) => p.postId == 10);
        expect(postA.relations['comments'], isA<List<Model>>());
      }
    });
  });

  group('RelationField.include', () {
    test(
      'empty children list yields a RelationLoadSpec with a single segment',
      () {
        final spec = _User$.posts.include(
          const <RelationField<Model, Model>>[],
        );
        expect(spec, isA<RelationLoadSpec>());
        // RelationLoadSpec is a typedef for RelationPath — instances
        // satisfy both type checks.
        expect(spec, isA<RelationPath>());
        expect(spec.path, 'posts');
        expect(spec.path.contains('.'), isFalse);
      },
    );

    test('non-empty children yields a dot-joined RelationLoadSpec path', () {
      final spec = _User$.posts.include(<RelationField<Model, Model>>[
        _Post$.comments,
      ]);
      expect(spec, isA<RelationLoadSpec>());
      expect(spec.path, 'posts.comments');
    });
  });

  group('withRelation API signature', () {
    test(
      'second positional parameter is a PredicateTree, not a callback; '
      'optional with default null so unconstrained calls still compile',
      () async {
        // Compile-time proof: the second positional arg accepts a
        // PredicateTree directly. If the signature regressed to a
        // RelationConstrain callback or a raw String, the next two
        // lines would not compile. Explicit types are intentional —
        // they encode the API contract in the test body.
        // ignore: omit_local_variable_types
        final PredicateTree predicate = _Post$.published.eq(true);
        // ignore: omit_local_variable_types
        final QueryBuilder<TUser> constrained = QueryBuilder<TUser>.from(
          _userContext(adapter),
        ).withRelation(_User$.posts, predicate);
        // ignore: omit_local_variable_types
        final QueryBuilder<TUser> unconstrained = QueryBuilder<TUser>.from(
          _userContext(adapter),
        ).withRelation(_User$.posts);
        expect(constrained, isA<QueryBuilder<TUser>>());
        expect(unconstrained, isA<QueryBuilder<TUser>>());

        // Behavioral parity: the predicate-form actually filters.
        final users = await constrained.get();
        final alice = users.firstWhere((u) => u.name == 'Alice');
        if (alice.relations['posts'] case final List<Model> list) {
          expect(list, hasLength(1));
        }
      },
    );
  });
}
