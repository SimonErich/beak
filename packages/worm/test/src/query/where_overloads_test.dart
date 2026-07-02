/// where(...) convenience overloads — equivalence
/// between `where(field, value)` and `where(field,
/// Operator.eq, value)`, plus whereRaw allow-raw
/// gating.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/configuration_exception.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_builder.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');

void main() {
  group('QueryBuilder where overloads', () {
    test(
      'where(field, value) is equivalent to where(field, eq, value)',
      () async {
        final adapter = await seededAdapter();
        final twoArg = QueryBuilder<TestUser>.from(
          userContext(adapter),
        ).where(_name, 'Alice');
        final threeArg = QueryBuilder<TestUser>.from(
          userContext(adapter),
        ).where(_name, Operator.eq, 'Alice');

        expect(
          twoArg.descriptor.where!.toMap(),
          equals(threeArg.descriptor.where!.toMap()),
        );

        final twoResults = await twoArg.get();
        final threeResults = await threeArg.get();
        expect(twoResults.map((u) => u.name).toList(), <String>['Alice']);
        expect(threeResults.map((u) => u.name).toList(), <String>['Alice']);
      },
    );

    test('where(field, op, value) with non-eq operator', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_age, Operator.gt, 30);
      final users = await qb.get();
      expect(
        users.map((u) => u.name).toSet(),
        equals(<String>{'Carol', 'Dave'}),
      );
    });

    test('where(PredicateTree) still accepted (back-compat)', () async {
      final adapter = await seededAdapter();
      final users = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name.eq('Bob')).get();
      expect(users.map((u) => u.name).toList(), <String>['Bob']);
    });

    test('where(invalid shape) throws ConfigurationException', () {
      // Passing a string as the first arg is not a valid shape.
      expect(
        () => QueryBuilder<TestUser>.from(
          userContext(InMemoryAdapter()),
        ).where('garbage'),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('orWhere(field, value) shorthand works', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name, 'Alice').orWhere(_name, 'Bob');
      final users = await qb.get();
      expect(
        users.map((u) => u.name).toSet(),
        equals(<String>{'Alice', 'Bob'}),
      );
    });

    test('where(field, Operator.like, pattern) filters by prefix', () async {
      final adapter = await seededAdapter();
      final users = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name, Operator.like, 'Al%').get();
      expect(users.map((u) => u.name).toList(), <String>['Alice']);
    });

    test(
      '2-arg form with non-Field first arg throws ArgumentError carrying the '
      'received runtimeType',
      () {
        final qb = QueryBuilder<TestUser>.from(userContext(InMemoryAdapter()));
        expect(
          () => qb.where('garbage', 5),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains('String'),
            ),
          ),
        );
      },
    );

    test(
      '3-arg form with non-Operator middle arg throws ArgumentError carrying '
      'the received runtimeType',
      () {
        final qb = QueryBuilder<TestUser>.from(userContext(InMemoryAdapter()));
        expect(
          () => qb.where(_name, 'not-an-operator', 'Alice'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains('String'),
            ),
          ),
        );
      },
    );
  });

  group('QueryBuilder whereRaw', () {
    test('whereRaw without allowRaw defaults false and throws', () {
      final qb = QueryBuilder<TestUser>.from(userContext(InMemoryAdapter()));
      expect(
        () => qb.whereRaw("name = 'Alice'"),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('whereRaw with allowRaw: false throws ConfigurationException', () {
      final qb = QueryBuilder<TestUser>.from(userContext(InMemoryAdapter()));
      expect(
        () => qb.whereRaw("name = 'Alice'"),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('whereRaw appends a RawNode predicate', () {
      final qb = QueryBuilder<TestUser>.from(userContext(InMemoryAdapter()))
          .whereRaw(
            "name = 'Alice'",
            parameters: const <Object?>[],
            allowRaw: true,
          );
      final where = qb.descriptor.where;
      expect(where, isA<RawNode>());
      if (where case final RawNode raw) {
        expect(raw.sql, "name = 'Alice'");
        expect(raw.parameters, isEmpty);
      } else {
        fail('Expected RawNode but got ${where.runtimeType}');
      }
    });

    test('RawNode.toMap exposes paramCount but never the raw values', () {
      const node = RawNode(
        'age > ? AND name = ?',
        parameters: <Object?>[18, 'Alice'],
      );
      final serialized = node.toMap();
      expect(serialized, <String, Object?>{
        'type': 'raw',
        'sql': 'age > ? AND name = ?',
        'paramCount': 2,
      });
      expect(serialized.containsKey('parameters'), isFalse);
    });

    test('whereRaw chains with limit() and additional where()', () async {
      final adapter = await seededAdapter();
      const ageField = ComparableField<num>('age');
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).whereRaw('1 = 1', allowRaw: true).limit(10).where(ageField, 30);
      expect(qb.descriptor.limit, 10);
      expect(qb.descriptor.where, isA<AndNode>());
    });

    test('get() on an InMemoryAdapter whereRaw query throws '
        'UnsupportedOperationException', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).whereRaw("name = 'Alice'", allowRaw: true);
      await expectLater(
        qb.get(),
        throwsA(isA<UnsupportedOperationException>()),
      );
    });

    test('Predicate predicate fields stay typed (smoke compile)', () {
      const predicate = Predicate(
        fieldName: 'age',
        operator: Operator.gte,
        value: 18,
      );
      expect(predicate.operator, Operator.gte);
    });
  });
}
