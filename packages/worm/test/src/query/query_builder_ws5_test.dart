/// QueryBuilder completeness: insertMany, withCount filter, typed
/// withRelations, and the SQL join / groupBy / having surface.
library;

import 'package:test/test.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/join_clause.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/sql_compiler.dart';
import 'package:worm/src/query/sql_query_context.dart';
import 'package:worm/src/relation/relation_base.dart';
import 'package:worm/src/relation/relation_field.dart';

import '_fixtures.dart';

void main() {
  group('insertMany', () {
    test('bulk-inserts and returns hydrated models', () async {
      final adapter = await seededAdapter();
      final inserted = await QueryBuilder<TestPost>.from(postContext(adapter))
          .insertMany(<Map<String, Object?>>[
            <String, Object?>{
              'id': 20,
              'user_id': 2,
              'title': 'New',
              'views': 5,
            },
            <String, Object?>{
              'id': 21,
              'user_id': 2,
              'title': 'New2',
              'views': 7,
            },
          ]);

      expect(inserted, hasLength(2));
      expect(inserted.first, isA<TestPost>());
      final all = await adapter.select(const QueryDescriptor(table: 'posts'));
      expect(all, hasLength(6));
    });

    test('empty rows is a no-op', () async {
      final adapter = await seededAdapter();
      final inserted = await QueryBuilder<TestPost>.from(
        postContext(adapter),
      ).insertMany(const <Map<String, Object?>>[]);
      expect(inserted, isEmpty);
    });
  });

  group('withCount filter', () {
    test('counts only related rows matching the filter', () async {
      final adapter = await seededAdapter();
      final ctx = userContext(
        adapter,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(ctx)
          .withCount(
            'posts',
            filter: const LeafNode(
              Predicate(fieldName: 'views', operator: Operator.gt, value: 150),
            ),
          )
          .get();

      final alice = users.firstWhere((u) => u.id == 1);
      // Alice's posts have views 100 and 200; only 200 > 150.
      expect(alice.getInjected<int>('postsCount'), 1);
    });
  });

  group('typed withRelations', () {
    test('eager-loads via typed RelationField companions', () async {
      final adapter = await seededAdapter();
      final ctx = userContext(
        adapter,
        relations: <String, Relation<Model, Model>>{
          'posts': userPostsRelation(),
        },
      );
      final users = await QueryBuilder<TestUser>.from(ctx).withRelations(
        const <RelationField<Model, Model>>[
          RelationField<Model, Model>('posts', foreignKey: 'user_id'),
        ],
      ).get();

      final alice = users.firstWhere((u) => u.id == 1);
      final posts = alice.relations['posts'];
      expect(posts, isA<List<Model>>());
      if (posts case final List<Model> list) {
        expect(list, hasLength(2));
      }
    });
  });

  group('SQL join / groupBy / having', () {
    test('SqlCompiler renders the full clause set', () {
      const descriptor = QueryDescriptor(
        table: 'users',
        joins: <JoinClause>[
          JoinClause(
            kind: JoinKind.inner,
            table: 'posts',
            leftColumn: 'posts.user_id',
            rightColumn: 'users.id',
          ),
        ],
        groupBy: <String>['users.id'],
        having: <HavingClause>[
          HavingClause(expression: 'COUNT(*)', operator: Operator.gt, value: 5),
        ],
      );
      const sql = SqlCompiler();
      expect(
        sql.compile(descriptor),
        'SELECT * FROM users INNER JOIN posts ON posts.user_id = users.id '
        'GROUP BY users.id HAVING COUNT(*) > 5',
      );
    });

    test(
      'SqlQueryContext builds joins / groupBy / having on the descriptor',
      () async {
        final adapter = await seededAdapter();
        final builder = QueryBuilder<TestUser>.from(userContext(adapter));
        final context = SqlQueryContext<TestUser>(builder)
            .join(
              'posts',
              const Field<Object?>('user_id', tableName: 'posts'),
              const Field<Object?>('id', tableName: 'users'),
            )
            .leftJoin(
              'profiles',
              const Field<Object?>('user_id', tableName: 'profiles'),
              const Field<Object?>('id', tableName: 'users'),
            )
            .groupBy(const <Field<Object?>>[
              Field<Object?>('id', tableName: 'users'),
            ])
            .having('COUNT(*)', Operator.gt, 5);

        final descriptor = context.builder.descriptor;
        expect(descriptor.joins, hasLength(2));
        expect(descriptor.groupBy, <String>['users.id']);
        expect(descriptor.having, hasLength(1));

        final sql = adapter.compileToString(descriptor);
        expect(sql, contains('INNER JOIN posts ON posts.user_id = users.id'));
        expect(
          sql,
          contains('LEFT JOIN profiles ON profiles.user_id = users.id'),
        );
        expect(sql, contains('GROUP BY users.id'));
        expect(sql, contains('HAVING COUNT(*) > 5'));
      },
    );
  });
}
