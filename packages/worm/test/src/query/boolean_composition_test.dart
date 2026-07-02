/// Boolean composition methods produce the expected
/// descriptor shapes, executable against the
/// InMemoryAdapter.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/sql_compiler.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');
const _userIdFk = ComparableField<int>('user_id');
const _id = ComparableField<int>('id');

QueryContext<TestPost> _postsContext(InMemoryAdapter adapter) =>
    QueryContext<TestPost>(
      adapter: adapter,
      table: 'posts',
      hydrate: TestPost.fromRow,
    );

void main() {
  group('QueryBuilder boolean composition', () {
    test('whereGroup wraps inner predicates in a GroupNode', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter))
          .where(_age.gte(30))
          .whereGroup(
            (q) => q.where(_name.eq('Alice')).orWhere(_name.eq('Carol')),
          );
      final where = qb.descriptor.where;
      expect(where, isA<AndNode>());
      expect(
        where,
        isA<AndNode>().having((n) => n.right, 'right', isA<GroupNode>()),
      );
    });

    test('whereGroup produces parenthesized SQL ((a OR b) AND c)', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter))
          .whereGroup(
            (q) => q.where(_name.eq('Alice')).orWhere(_name.eq('Bob')),
          )
          .where(_age.gte(18));
      const compiler = SqlCompiler();
      final sql = compiler.compile(qb.descriptor);
      expect(
        sql,
        r'SELECT * FROM users WHERE '
        "(name = 'Alice' OR name = 'Bob') AND age >= 18",
      );
    });

    test('whereGroup actually filters rows (executable)', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter))
          .where(_age.gte(18))
          .whereGroup(
            (q) => q.where(_name.eq('Alice')).orWhere(_name.eq('Dave')),
          );
      final results = await qb.get();
      final names = results.map((u) => u.name).toSet();
      expect(names, equals(<String>{'Alice', 'Dave'}));
    });

    test('whereExists produces EXISTS in SQL', () async {
      final adapter = await seededAdapter();
      final users = QueryBuilder<TestUser>.from(userContext(adapter));
      final posts = QueryBuilder<TestPost>.from(
        _postsContext(adapter),
      ).where(_userIdFk.eq(1));
      final qb = users.whereExists(posts);
      const compiler = SqlCompiler();
      final sql = compiler.compile(qb.descriptor);
      expect(sql, contains('EXISTS ('));
      expect(sql, contains('FROM posts'));
    });

    test('whereExists evaluates uncorrelated subquery in-memory', () async {
      final adapter = await seededAdapter();
      final results = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).whereExists(QueryBuilder<TestPost>.from(_postsContext(adapter))).get();
      // Posts table is non-empty, so every user row passes.
      expect(results, hasLength(4));
    });

    test('whereNotExists is the inverse of whereExists', () async {
      final adapter = await seededAdapter();
      final empty = QueryBuilder<TestPost>.from(
        _postsContext(adapter),
      ).where(_userIdFk.eq(9999));
      final results = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).whereNotExists(empty).get();
      expect(results, hasLength(4));
    });

    test('whereColumn compiles to column comparison', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).whereColumn(_id, const ComparableField<int>('age'));
      const compiler = SqlCompiler();
      final sql = compiler.compile(qb.descriptor);
      expect(sql, 'SELECT * FROM users WHERE id = age');
    });

    test('whereColumn with custom operator', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter)).whereColumn(
        _id,
        const ComparableField<int>('age'),
        operator: Operator.lt,
      );
      const compiler = SqlCompiler();
      final sql = compiler.compile(qb.descriptor);
      expect(sql, 'SELECT * FROM users WHERE id < age');
    });

    test('whereGroup with empty callback is a no-op', () async {
      final adapter = await seededAdapter();
      final base = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_age.gte(18));
      final grouped = base.whereGroup((q) => q);
      expect(identical(base, grouped), isTrue);
    });

    test(
      'whereGroup wraps a single OrNode of (a, b) inside a GroupNode',
      () async {
        final adapter = await seededAdapter();
        final qb = QueryBuilder<TestUser>.from(userContext(adapter)).whereGroup(
          (q) => q.where(_name.eq('Alice')).orWhere(_name.eq('Carol')),
        );
        final where = qb.descriptor.where;
        expect(where, isA<GroupNode>());
        expect(
          where,
          isA<GroupNode>().having((g) => g.child, 'child', isA<OrNode>()),
        );
      },
    );

    test('whereExists descriptor.toMap embeds the subquery descriptor', () {
      const descriptor = QueryDescriptor(
        table: 'posts',
        where: LeafNode(
          Predicate(fieldName: 'user_id', operator: Operator.eq, value: 1),
        ),
      );
      const node = ExistsNode(QueryDescriptor(table: 'posts'));
      const negated = ExistsNode(descriptor, negated: true);
      expect(node.toMap()['type'], 'exists');
      expect(node.toMap()['subquery'], isA<Map<String, Object?>>());
      expect(negated.toMap()['type'], 'notExists');
    });

    test('ColumnNode.toMap shape is {type, left, right, operator}', () {
      const node = ColumnNode(
        leftField: 'id',
        rightField: 'age',
        operator: Operator.eq,
      );
      expect(node.toMap(), <String, Object?>{
        'type': 'column',
        'left': 'id',
        'right': 'age',
        'operator': 'eq',
      });
    });
  });
}
