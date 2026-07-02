import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/exception/full_table_scan_exception.dart';
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

QueryContext<TestUser> _ctx(DatabaseAdapter adapter) => QueryContext<TestUser>(
  adapter: adapter,
  table: 'users',
  hydrate: TestUser.fromRow,
);

/// Adapter wrapper that records the number of read,
/// update, and delete calls executed against it.
///
/// Used by bulk-op tests to assert that
/// `QueryBuilder.update()` / `QueryBuilder.delete()`
/// issue exactly one underlying call and never read
/// rows back through `select()`.
final class _RecordingAdapter extends DatabaseAdapter {
  _RecordingAdapter(this._inner) : super(capabilities: _inner.capabilities);

  final InMemoryAdapter _inner;

  int selectCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor) {
    selectCalls++;
    return _inner.select(descriptor);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor) {
    selectCalls++;
    return _inner.selectOne(descriptor);
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor descriptor) =>
      _inner.insert(descriptor);

  @override
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor descriptor,
  ) => _inner.insertMany(descriptor);

  @override
  Future<int> update(UpdateDescriptor descriptor) {
    updateCalls++;
    return _inner.update(descriptor);
  }

  @override
  Future<int> delete(DeleteDescriptor descriptor) {
    deleteCalls++;
    return _inner.delete(descriptor);
  }

  @override
  Future<int> count(AggregateDescriptor descriptor) => _inner.count(descriptor);

  @override
  Future<num?> sum(AggregateDescriptor descriptor) => _inner.sum(descriptor);

  @override
  Future<double?> avg(AggregateDescriptor descriptor) => _inner.avg(descriptor);

  @override
  Future<Object?> min(AggregateDescriptor descriptor) => _inner.min(descriptor);

  @override
  Future<Object?> max(AggregateDescriptor descriptor) => _inner.max(descriptor);

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
  Future<void> executeSchema(SchemaDescriptor descriptor) =>
      _inner.executeSchema(descriptor);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _inner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor descriptor) =>
      _inner.stream(descriptor);

  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}

void main() {
  group('QueryBuilder bulk update', () {
    test('where(...).update(...) calls adapter.update() exactly once '
        'and returns affected count', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      final changed = await QueryBuilder<TestUser>.from(ctx)
          .where(const ComparableField<int>('id').eq(1))
          .update(const <String, Object?>{'name': 'Updated'});
      expect(changed, 1);
      expect(adapter.updateCalls, 1);
      // AC: updateAll() does not call adapter.select().
      expect(adapter.selectCalls, 0);
    });

    test('update() does not hydrate models or call adapter.select()', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      await QueryBuilder<TestUser>.from(ctx)
          .where(const StringField('name').eq('Alice'))
          .update(const <String, Object?>{'age': 31});
      expect(adapter.selectCalls, 0);
    });

    test('update() without WHERE and preventFullTableScans=true throws '
        'FullTableScanException before calling adapter.update()', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      final qb = QueryBuilder<TestUser>.from(
        ctx,
        strictness: const StrictnessConfig(preventFullTableScans: true),
      );
      await expectLater(
        () => qb.update(const <String, Object?>{'age': 0}),
        throwsA(isA<FullTableScanException>()),
      );
      expect(adapter.updateCalls, 0);
    });

    test('update() without WHERE and preventDestructiveWithoutWhere=true '
        'throws FullTableScanException', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      final qb = QueryBuilder<TestUser>.from(
        ctx,
        strictness: const StrictnessConfig(
          preventDestructiveWithoutWhere: true,
        ),
      );
      await expectLater(
        () => qb.update(const <String, Object?>{'age': 0}),
        throwsA(isA<FullTableScanException>()),
      );
      expect(adapter.updateCalls, 0);
    });
  });

  group('QueryBuilder bulk delete', () {
    test('where(ageField.lt(18)).delete() calls adapter.delete() once '
        'and returns affected count (zero on this fixture)', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      final removed = await QueryBuilder<TestUser>.from(
        ctx,
      ).where(const ComparableField<int>('age').lt(18)).delete();
      // Fixture has no users under 18, so affected is 0.
      // The AC's invariant — single adapter call returning
      // the affected count — still holds.
      expect(removed, 0);
      expect(adapter.deleteCalls, 1);
      expect(adapter.selectCalls, 0);
    });

    test(
      'where(ageField.lt(28)).delete() deletes the one matching row',
      () async {
        final inner = await seededAdapter();
        final adapter = _RecordingAdapter(inner);
        final ctx = _ctx(adapter);
        final removed = await QueryBuilder<TestUser>.from(
          ctx,
        ).where(const ComparableField<int>('age').lt(28)).delete();
        expect(removed, 1);
        expect(adapter.deleteCalls, 1);
        expect(adapter.selectCalls, 0);
      },
    );

    test('delete() without WHERE and preventFullTableScans=false '
        'succeeds and deletes all rows', () async {
      final inner = await seededAdapter();
      final adapter = _RecordingAdapter(inner);
      final ctx = _ctx(adapter);
      final removed = await QueryBuilder<TestUser>.from(ctx).delete();
      expect(removed, 4);
      expect(adapter.deleteCalls, 1);
    });

    test(
      'delete() without WHERE and preventFullTableScans=true throws',
      () async {
        final inner = await seededAdapter();
        final adapter = _RecordingAdapter(inner);
        final ctx = _ctx(adapter);
        final qb = QueryBuilder<TestUser>.from(
          ctx,
          strictness: const StrictnessConfig(preventFullTableScans: true),
        );
        await expectLater(qb.delete, throwsA(isA<FullTableScanException>()));
        expect(adapter.deleteCalls, 0);
      },
    );
  });
}
