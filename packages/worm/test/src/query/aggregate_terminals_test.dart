/// Scalar aggregate terminals push down to the
/// adapter and produce correct values against the
/// InMemoryAdapter.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/cast_exception.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';

import '_fixtures.dart';

const _age = ComparableField<num>('age');
const _name = StringField('name');

QueryContext<TestUser> _userContext(DatabaseAdapter adapter) =>
    QueryContext<TestUser>(
      adapter: adapter,
      table: 'users',
      hydrate: TestUser.fromRow,
    );

/// Adapter wrapper that records every aggregate call
/// and forwards to a delegate. Lets tests prove that
/// `sum`/`avg`/`min`/`max` push the work down to the
/// adapter — never iterating rows.
final class _RecordingAdapter extends DatabaseAdapter {
  _RecordingAdapter(this._inner);

  final InMemoryAdapter _inner;

  /// Each entry is `<function>(<column>)`.
  final List<String> aggregateCalls = <String>[];

  /// Each entry is the descriptor table for `select`
  /// calls — used to assert no row iteration during
  /// aggregates.
  final List<String> selectCalls = <String>[];

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    selectCalls.add(d.table);
    return _inner.select(d);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _inner.selectOne(d);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _inner.insert(d);

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _inner.insertMany(d);

  @override
  Future<int> update(UpdateDescriptor d) => _inner.update(d);

  @override
  Future<int> delete(DeleteDescriptor d) => _inner.delete(d);

  @override
  Future<int> count(AggregateDescriptor d) {
    aggregateCalls.add('count(${d.column ?? '*'})');
    return _inner.count(d);
  }

  @override
  Future<num?> sum(AggregateDescriptor d) {
    aggregateCalls.add('sum(${d.column})');
    return _inner.sum(d);
  }

  @override
  Future<double?> avg(AggregateDescriptor d) {
    aggregateCalls.add('avg(${d.column})');
    return _inner.avg(d);
  }

  @override
  Future<Object?> min(AggregateDescriptor d) {
    aggregateCalls.add('min(${d.column})');
    return _inner.min(d);
  }

  @override
  Future<Object?> max(AggregateDescriptor d) {
    aggregateCalls.add('max(${d.column})');
    return _inner.max(d);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => _inner.rawQuery(query, parameters);

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      _inner.rawExecute(statement, parameters);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _inner.transaction(action);

  @override
  Future<void> executeSchema(SchemaDescriptor d) => _inner.executeSchema(d);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _inner.stream(d);

  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}

void main() {
  group('QueryBuilder scalar aggregates', () {
    test('sum(field) pushes down to adapter, no row iteration', () async {
      final inner = await seededAdapter();
      final recording = _RecordingAdapter(inner);
      final qb = QueryBuilder<TestUser>.from(_userContext(recording));
      final total = await qb.sum(_age);
      // Alice(30) + Bob(25) + Carol(40) + Dave(35) = 130.
      expect(total, 130);
      expect(recording.aggregateCalls, <String>['sum(age)']);
      expect(recording.selectCalls, isEmpty);
    });

    test('avg(field) pushes down to adapter, no row iteration', () async {
      final inner = await seededAdapter();
      final recording = _RecordingAdapter(inner);
      final qb = QueryBuilder<TestUser>.from(_userContext(recording));
      final avg = await qb.avg(_age);
      expect(avg, closeTo(32.5, 0.0001));
      expect(recording.aggregateCalls, <String>['avg(age)']);
      expect(recording.selectCalls, isEmpty);
    });

    test('min(field) pushes down to adapter, no row iteration', () async {
      final inner = await seededAdapter();
      final recording = _RecordingAdapter(inner);
      final qb = QueryBuilder<TestUser>.from(_userContext(recording));
      final min = await qb.min<int>(const ComparableField<int>('age'));
      expect(min, 25);
      expect(recording.aggregateCalls, <String>['min(age)']);
      expect(recording.selectCalls, isEmpty);
    });

    test('max(field) pushes down to adapter, no row iteration', () async {
      final inner = await seededAdapter();
      final recording = _RecordingAdapter(inner);
      final qb = QueryBuilder<TestUser>.from(_userContext(recording));
      final max = await qb.max<int>(const ComparableField<int>('age'));
      expect(max, 40);
      expect(recording.aggregateCalls, <String>['max(age)']);
      expect(recording.selectCalls, isEmpty);
    });

    test('sum respects WHERE constraints', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final sum = await qb.where(_age.gte(30)).sum(_age);
      // Alice(30) + Carol(40) + Dave(35) = 105.
      expect(sum, 105);
    });

    test('sum returns null for empty result set', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final sum = await qb.where(_age.gte(999)).sum(_age);
      expect(sum, isNull);
    });

    test('max<String> returns lexicographically largest value', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final largest = await qb.max<String>(_name);
      expect(largest, 'Dave');
    });

    test('min returns null when no rows match WHERE', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final smallest = await qb
          .where(_age.gte(999))
          .min<int>(const ComparableField<int>('age'));
      expect(smallest, isNull);
    });

    test('max returns null when no rows match WHERE', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final largest = await qb
          .where(_age.gte(999))
          .max<int>(const ComparableField<int>('age'));
      expect(largest, isNull);
    });

    test('avg respects WHERE constraints', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final avg = await qb.where(_age.gte(30)).avg(_age);
      // (30 + 40 + 35) / 3 = 35.
      expect(avg, closeTo(35, 0.0001));
    });

    test(
      'WHERE clause flows into AggregateDescriptor passed to adapter',
      () async {
        final inner = await seededAdapter();
        final recording = _RecordingAdapter(inner);
        final qb = QueryBuilder<TestUser>.from(_userContext(recording));
        await qb.where(_age.gte(30)).sum(_age);
        expect(recording.aggregateCalls, <String>['sum(age)']);
        expect(recording.selectCalls, isEmpty);
      },
    );

    test('min<V> throws CastException on type mismatch', () async {
      final adapter = await seededAdapter();
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      // 'age' rows are int — request String to force a
      // runtime type mismatch and prove the failure
      // surfaces rather than silently returning null.
      expect(
        () => qb.min<String>(const StringField('age')),
        throwsA(isA<CastException>()),
      );
    });
  });
}
