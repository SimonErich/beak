/// Query inspection: toSql, toMongoFilter, debug,
/// explain. Golden snapshots cover toSql and
/// toMongoFilter for representative queries.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');
const _userIdFk = ComparableField<int>('user_id');

void _expectGolden(String name, String actual) {
  final file = File('test/goldens/inspection/$name.golden');
  final update = Platform.environment['UPDATE_GOLDENS'] == 'true';
  if (update || !file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$actual\n');
  }
  final expected = file.readAsStringSync().trimRight();
  expect(actual, equals(expected));
}

QueryBuilder<TestUser> _users(InMemoryAdapter adapter) =>
    QueryBuilder<TestUser>.from(userContext(adapter));

void main() {
  group('QueryBuilder.toSql() golden snapshots', () {
    final adapter = InMemoryAdapter();

    test('plain select all', () {
      _expectGolden('toSql_01_plain', _users(adapter).toSql());
    });

    test('where with literal value', () {
      _expectGolden(
        'toSql_02_where_eq',
        _users(adapter).where(_name, 'Alice').toSql(),
      );
    });

    test('where gte + ordering + limit', () {
      _expectGolden(
        'toSql_03_complex',
        _users(adapter)
            .where(_age, Operator.gte, 18)
            .orderBy(_age, descending: true)
            .limit(10)
            .toSql(),
      );
    });

    test('whereGroup produces parenthesized SQL', () {
      _expectGolden(
        'toSql_04_group',
        _users(adapter)
            .whereGroup((q) => q.where(_name, 'Alice').orWhere(_name, 'Bob'))
            .where(_age, Operator.gte, 18)
            .toSql(),
      );
    });

    test('whereExists compiles to EXISTS', () {
      final posts = QueryBuilder<TestPost>.from(
        postContext(adapter),
      ).where(_userIdFk, 1);
      _expectGolden(
        'toSql_05_exists',
        _users(adapter).whereExists(posts).toSql(),
      );
    });

    test('whereColumn compiles to column comparison', () {
      _expectGolden(
        'toSql_06_column',
        _users(adapter)
            .whereColumn(
              const ComparableField<int>('id'),
              const ComparableField<int>('age'),
            )
            .toSql(),
      );
    });

    test('whereRaw renders the fragment verbatim', () {
      _expectGolden(
        'toSql_07_raw',
        _users(
          adapter,
        ).whereRaw('id IN (SELECT id FROM banned)', allowRaw: true).toSql(),
      );
    });
  });

  group('QueryBuilder.toMongoFilter() golden snapshots', () {
    final adapter = InMemoryAdapter();

    test('plain select all = empty filter', () {
      _expectGolden('toMongo_01_plain', _users(adapter).toMongoFilter());
    });

    test('where eq', () {
      _expectGolden(
        'toMongo_02_where_eq',
        _users(adapter).where(_name, 'Alice').toMongoFilter(),
      );
    });

    test('whereExists pipeline', () {
      final posts = QueryBuilder<TestPost>.from(
        postContext(adapter),
      ).where(_userIdFk, 1);
      _expectGolden(
        'toMongo_03_exists',
        _users(adapter).whereExists(posts).toMongoFilter(),
      );
    });

    test(r'whereGroup renders as nested $and', () {
      _expectGolden(
        'toMongo_04_group',
        _users(adapter)
            .whereGroup((q) => q.where(_name, 'Alice').orWhere(_name, 'Bob'))
            .where(_age, Operator.gte, 18)
            .toMongoFilter(),
      );
    });
  });

  group('QueryBuilder.debug()', () {
    test('debug() returns the identical builder for fluent chaining', () async {
      final adapter = await seededAdapter();
      final qb = _users(adapter).where(_age.gte(18));
      final returned = qb.debug();
      expect(identical(qb, returned), isTrue);
    });

    test('debug() does not mutate descriptor state', () async {
      final adapter = await seededAdapter();
      final qb = _users(adapter).where(_age.gte(18)).limit(7);
      final beforeWhere = qb.descriptor.where?.toMap();
      final beforeLimit = qb.descriptor.limit;
      qb.debug();
      expect(qb.descriptor.where?.toMap(), equals(beforeWhere));
      expect(qb.descriptor.limit, beforeLimit);
    });

    test('debug() never throws on complex predicates', () async {
      final adapter = await seededAdapter();
      final qb = _users(adapter)
          .whereGroup((q) => q.where(_name, 'Alice').orWhere(_name, 'Bob'))
          .whereExists(QueryBuilder<TestPost>.from(postContext(adapter)))
          .where(_age, Operator.gte, 18)
          .orderBy(_age, descending: true)
          .limit(10);
      expect(qb.debug, returnsNormally);
    });

    test('debug() still works after the query is executed', () async {
      final adapter = await seededAdapter();
      final qb = _users(adapter).where(_age.gte(18));
      await qb.get();
      expect(qb.debug, returnsNormally);
    });
  });

  group('QueryBuilder.explain()', () {
    test(
      'returns ExplainResult with usesIndex == true on InMemoryAdapter',
      () async {
        final adapter = await seededAdapter();
        final plan = await _users(adapter).explain();
        expect(plan.usesIndex, isTrue);
        expect(plan.raw, contains('InMemoryAdapter'));
      },
    );

    test(
      'throws UnsupportedOperationException when adapter lacks ExplainCapable',
      () async {
        final adapter = _NoExplainAdapter();
        final qb = QueryBuilder<TestUser>.from(
          QueryContext<TestUser>(
            adapter: adapter,
            table: 'users',
            hydrate: TestUser.fromRow,
          ),
        );
        await expectLater(
          qb.explain(),
          throwsA(isA<UnsupportedOperationException>()),
        );
      },
    );
  });
}

/// Adapter that does not mix in `ExplainCapable`, so
/// `QueryBuilder.explain` must throw against it.
final class _NoExplainAdapter extends DatabaseAdapter {
  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) async =>
      <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async => null;

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) async =>
      <String, Object?>{};

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) async =>
      <Map<String, Object?>>[];

  @override
  Future<int> update(UpdateDescriptor d) async => 0;

  @override
  Future<int> delete(DeleteDescriptor d) async => 0;

  @override
  Future<int> count(AggregateDescriptor d) async => 0;

  @override
  Future<num?> sum(AggregateDescriptor d) async => null;

  @override
  Future<double?> avg(AggregateDescriptor d) async => null;

  @override
  Future<Object?> min(AggregateDescriptor d) async => null;

  @override
  Future<Object?> max(AggregateDescriptor d) async => null;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) async => <Map<String, Object?>>[];

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) async => 0;

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      action(this);

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {}

  @override
  Future<Map<String, List<String>>> introspectSchema() async =>
      <String, List<String>>{};

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) =>
      const Stream<Map<String, Object?>>.empty();

  @override
  String compileToString(Object descriptor) => 'no-explain';
}
