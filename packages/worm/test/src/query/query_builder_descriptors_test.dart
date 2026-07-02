import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');
const _userId = ComparableField<int>('id');

QueryBuilder<TestUser> builder() {
  final adapter = InMemoryAdapter();
  return QueryBuilder<TestUser>.from(userContext(adapter));
}

void main() {
  group('QueryBuilder descriptors (15 query shapes)', () {
    test('1. plain select all', () {
      final descriptor = builder().descriptor.toMap();
      expect(descriptor, <String, Object?>{'type': 'query', 'table': 'users'});
    });

    test('2. where equality', () {
      final descriptor = builder().where(_name.eq('Alice')).descriptor.toMap();
      expect(descriptor['where'], <String, Object?>{
        'type': 'leaf',
        'field': 'name',
        'operator': 'eq',
        'value': 'Alice',
      });
    });

    test('3. where comparison gte', () {
      final descriptor = builder().where(_age.gte(18)).descriptor.toMap();
      expect(descriptor['where'], <String, Object?>{
        'type': 'leaf',
        'field': 'age',
        'operator': 'gte',
        'value': 18,
      });
    });

    test('4. where AND combination', () {
      final descriptor = builder()
          .where(_age.gte(18))
          .where(_name.eq('Alice'))
          .descriptor
          .toMap();
      expect(descriptor['where'], isA<Map<String, Object?>>());
      expect((descriptor['where']! as Map<String, Object?>)['type'], 'and');
    });

    test('5. orWhere disjunction', () {
      final descriptor = builder()
          .where(_name.eq('Alice'))
          .orWhere(_name.eq('Bob'))
          .descriptor
          .toMap();
      expect((descriptor['where']! as Map<String, Object?>)['type'], 'or');
    });

    test('6. inList', () {
      final descriptor = builder().where(_userId.inList(<int>[1, 2, 3]));
      expect(descriptor.descriptor.where, isNotNull);
      expect(descriptor.descriptor.toMap()['where'], <String, Object?>{
        'type': 'leaf',
        'field': 'id',
        'operator': 'inList',
        'value': <int>[1, 2, 3],
      });
    });

    test('7. between', () {
      final descriptor = builder().where(_age.between(18, 65)).descriptor;
      expect(
        (descriptor.toMap()['where']! as Map<String, Object?>)['operator'],
        'between',
      );
    });

    test('8. like contains', () {
      final descriptor = builder().where(_name.contains('al'));
      expect(
        (descriptor.descriptor.toMap()['where']!
            as Map<String, Object?>)['value'],
        '%al%',
      );
    });

    test('9. isNull', () {
      final descriptor = builder()
          .where(const Field<Object?>('deleted_at').isNull())
          .descriptor
          .toMap();
      expect(
        (descriptor['where']! as Map<String, Object?>)['operator'],
        'isNull',
      );
    });

    test('10. orderBy single', () {
      final descriptor = builder().orderBy(_age).descriptor.toMap();
      expect(descriptor['orderBy'], <Object>[
        <String, Object?>{'field': 'age', 'direction': 'asc'},
      ]);
    });

    test('11. orderBy descending', () {
      final descriptor = builder()
          .orderBy(_age, descending: true)
          .descriptor
          .toMap();
      expect(descriptor['orderBy'], <Object>[
        <String, Object?>{'field': 'age', 'direction': 'desc'},
      ]);
    });

    test('12. limit + offset', () {
      final descriptor = builder().limit(10).offset(20).descriptor.toMap();
      expect(descriptor['limit'], 10);
      expect(descriptor['offset'], 20);
    });

    test('13. select columns', () {
      final descriptor = builder()
          .select(const <Field<Object?>>[
            Field<Object?>('id'),
            Field<Object?>('name'),
          ])
          .descriptor
          .toMap();
      expect(descriptor['columns'], <String>['id', 'name']);
    });

    test('14. distinct', () {
      final descriptor = builder().distinct().descriptor.toMap();
      expect(descriptor['distinct'], true);
    });

    test('15. composite: where + orderBy + limit + offset + distinct', () {
      final descriptor = builder()
          .where(_age.gte(18))
          .orderBy(_age, descending: true)
          .limit(5)
          .offset(10)
          .distinct()
          .descriptor
          .toMap();
      expect(descriptor, <String, Object?>{
        'type': 'query',
        'table': 'users',
        'where': <String, Object?>{
          'type': 'leaf',
          'field': 'age',
          'operator': 'gte',
          'value': 18,
        },
        'orderBy': <Map<String, Object?>>[
          <String, Object?>{'field': 'age', 'direction': 'desc'},
        ],
        'limit': 5,
        'offset': 10,
        'distinct': true,
      });
    });
  });

  group('QueryBuilder is immutable', () {
    test('each chain returns a new builder', () {
      final original = builder();
      final modified = original.where(_age.gte(18));
      expect(original.descriptor.where, isNull);
      expect(modified.descriptor.where, isNotNull);
    });
  });
}
