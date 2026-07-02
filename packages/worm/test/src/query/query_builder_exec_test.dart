import 'package:test/test.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/exception/full_table_scan_exception.dart';
import 'package:worm/src/exception/model_not_found_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/query_builder.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');

void main() {
  group('QueryBuilder terminal methods', () {
    test('get() returns all hydrated models', () async {
      final adapter = await seededAdapter();
      final users = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).get();
      expect(users, hasLength(4));
      expect(users.first.name, 'Alice');
    });

    test('first() returns first model or null', () async {
      final adapter = await seededAdapter();
      final user = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name.eq('Bob')).first();
      expect(user, isNotNull);
      expect(user!.name, 'Bob');
    });

    test('first() returns null when no match', () async {
      final adapter = await seededAdapter();
      final user = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name.eq('Zoe')).first();
      expect(user, isNull);
    });

    test('firstOrFail throws ModelNotFoundException on empty', () async {
      final adapter = await seededAdapter();
      expect(
        () => QueryBuilder<TestUser>.from(
          userContext(adapter),
        ).where(_name.eq('Zoe')).firstOrFail(),
        throwsA(isA<ModelNotFoundException>()),
      );
    });

    test('find/findOrFail lookup by primary key', () async {
      final adapter = await seededAdapter();
      final user = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).find(1);
      expect(user?.name, 'Alice');
      expect(
        () => QueryBuilder<TestUser>.from(userContext(adapter)).findOrFail(999),
        throwsA(isA<ModelNotFoundException>()),
      );
    });

    test('count() returns scalar', () async {
      final adapter = await seededAdapter();
      final count = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_age.gte(30)).count();
      expect(count, 3);
    });

    test('exists() returns bool', () async {
      final adapter = await seededAdapter();
      final exists = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_name.eq('Alice')).exists();
      expect(exists, isTrue);
    });

    test('pluck() returns column values', () async {
      final adapter = await seededAdapter();
      final names = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).pluck<String>(const StringField('name'));
      expect(names, containsAll(<String>['Alice', 'Bob', 'Carol', 'Dave']));
    });
  });

  group('QueryBuilder bulk update / delete', () {
    test('update() executes single statement, no hydration', () async {
      final adapter = await seededAdapter();
      final changed = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_age.gte(35)).update(const <String, Object?>{'age': 99});
      expect(changed, 2);
      final updated = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(const ComparableField<int>('age').eq(99)).get();
      expect(updated, hasLength(2));
    });

    test('delete() executes single statement, no hydration', () async {
      final adapter = await seededAdapter();
      final removed = await QueryBuilder<TestUser>.from(
        userContext(adapter),
      ).where(_age.gte(35)).delete();
      expect(removed, 2);
    });
  });

  group('QueryBuilder strictness', () {
    test('preventFullTableScans blocks unfiltered select', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
        strictness: const StrictnessConfig(preventFullTableScans: true),
      );
      expect(qb.get, throwsA(isA<FullTableScanException>()));
    });

    test('preventDestructiveWithoutWhere blocks unfiltered delete', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
        strictness: const StrictnessConfig(
          preventDestructiveWithoutWhere: true,
        ),
      );
      expect(qb.delete, throwsA(isA<FullTableScanException>()));
    });

    test('preventDestructiveWithoutWhere blocks unfiltered update', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
        strictness: const StrictnessConfig(
          preventDestructiveWithoutWhere: true,
        ),
      );
      expect(
        () => qb.update(const <String, Object?>{'age': 0}),
        throwsA(isA<FullTableScanException>()),
      );
    });

    test('strictness allows update with WHERE present', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
        strictness: const StrictnessConfig(
          preventDestructiveWithoutWhere: true,
        ),
      );
      final updated = await qb.where(_name.eq('Alice')).update(
        const <String, Object?>{'age': 31},
      );
      expect(updated, 1);
    });
  });
}
