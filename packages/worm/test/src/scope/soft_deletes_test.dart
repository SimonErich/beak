import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/model/soft_deletes.dart';
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
import 'package:worm/src/scope/global_scope.dart';
import 'package:worm/src/scope/soft_delete_scope.dart';

import '../query/_fixtures.dart';

T _read<T>(Map<String, Object?> row, String key, T fallback) {
  final value = row[key];
  if (value is T) return value;
  return fallback;
}

DateTime? _readDateTime(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Model with soft-delete semantics used by the
/// instance-method tests.
final class _SoftUser extends Model with SoftDeletes {
  _SoftUser({
    required this.userId,
    required this.name,
    required this.adapter,
    DateTime? deletedAt,
  }) {
    if (deletedAt != null) this.deletedAt = deletedAt;
  }

  factory _SoftUser.fromRow(
    Map<String, Object?> row, {
    required DatabaseAdapter adapter,
  }) => _SoftUser(
    userId: _read<int>(row, 'id', 0),
    name: _read<String>(row, 'name', ''),
    deletedAt: _readDateTime(row, softDeleteColumn),
    adapter: adapter,
  );

  final int userId;
  final String name;
  final DatabaseAdapter adapter;

  @override
  Object get id => userId;

  @override
  DatabaseAdapter get softDeleteAdapter => adapter;

  @override
  String get softDeleteTable => 'soft_users';

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': userId,
    'name': name,
    softDeleteColumn: deletedAt?.toIso8601String(),
  };
}

/// Soft-delete model that records restore lifecycle hooks and can
/// cancel the restore via [cancelRestore].
final class _HookedSoftUser extends Model with SoftDeletes {
  _HookedSoftUser({required this.adapter, this.cancelRestore = false}) {
    deletedAt = DateTime(2020);
  }

  final DatabaseAdapter adapter;
  final bool cancelRestore;
  final List<String> events = <String>[];

  @override
  Object get id => 1;

  @override
  DatabaseAdapter get softDeleteAdapter => adapter;

  @override
  String get softDeleteTable => 'soft_users';

  @override
  Map<String, Object?> toRow() => <String, Object?>{
    'id': 1,
    'name': 'Hooked',
    softDeleteColumn: deletedAt?.toIso8601String(),
  };

  @override
  Future<bool> beforeRestore() async {
    events.add('beforeRestore');
    return !cancelRestore;
  }

  @override
  Future<void> afterRestore() async => events.add('afterRestore');
}

Future<InMemoryAdapter> _softUserAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'soft_users'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'soft_users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Alice', softDeleteColumn: null},
        <String, Object?>{'id': 2, 'name': 'Bob', softDeleteColumn: null},
      ],
    ),
  );
  return adapter;
}

QueryContext<_SoftUser> _softUserContext(DatabaseAdapter adapter) =>
    QueryContext<_SoftUser>(
      adapter: adapter,
      table: 'soft_users',
      hydrate: (row) => _SoftUser.fromRow(row, adapter: adapter),
      globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<_SoftUser>()],
    );

QueryContext<TestUser> _testUserContext(DatabaseAdapter adapter) =>
    QueryContext<TestUser>(
      adapter: adapter,
      table: 'users',
      hydrate: TestUser.fromRow,
      globalScopes: const <GlobalScope<Model>>[SoftDeleteScope<TestUser>()],
    );

void main() {
  group('SoftDeleteScope (query side)', () {
    test('default query returns only rows where deleted_at IS NULL', () async {
      final adapter = await seededAdapter();
      final live = await QueryBuilder<TestUser>.from(
        _testUserContext(adapter),
      ).get();
      expect(live, hasLength(3));
      expect(live.every((u) => u.deletedAt == null), isTrue);
      expect(live.map((u) => u.name), isNot(contains('Carol')));
    });

    test('withTrashed() returns all rows including soft-deleted', () async {
      final adapter = await seededAdapter();
      final all = await QueryBuilder<TestUser>.from(
        _testUserContext(adapter),
      ).withTrashed().get();
      expect(all, hasLength(4));
      expect(all.map((u) => u.name), contains('Carol'));
    });

    test(
      'onlyTrashed() returns only rows where deleted_at IS NOT NULL',
      () async {
        final adapter = await seededAdapter();
        final trashed = await QueryBuilder<TestUser>.from(
          _testUserContext(adapter),
        ).onlyTrashed().get();
        expect(trashed, hasLength(1));
        expect(trashed.first.name, 'Carol');
        expect(trashed.first.deletedAt, isNotNull);
      },
    );

    test('SoftDeleteScope.name is the documented constant', () {
      const scope = SoftDeleteScope<TestUser>();
      expect(scope.name, softDeleteScopeName);
      expect(softDeleteScopeName, 'soft_deletes');
    });

    test('soft-delete column constant is "deleted_at"', () {
      expect(softDeleteColumn, 'deleted_at');
    });
  });

  group('SoftDeletes instance methods', () {
    test(
      'model.delete() sets deleted_at to a DateTime and calls save()',
      () async {
        final adapter = await _softUserAdapter();
        final ctx = _softUserContext(adapter);
        final user = await QueryBuilder<_SoftUser>.from(
          ctx,
        ).where(const ComparableField<int>('id').eq(1)).first();
        expect(user, isNotNull);
        expect(user!.deletedAt, isNull);

        await user.delete();

        expect(user.deletedAt, isA<DateTime>());
        expect(user.deletedAt, isNotNull);

        // The row still exists in the table — soft delete
        // never calls adapter.delete().
        final rows = await adapter.select(
          QueryDescriptor(
            table: 'soft_users',
            where: const ComparableField<int>('id').eq(1),
          ),
        );
        expect(rows, hasLength(1));
        expect(rows.first[softDeleteColumn], isNotNull);
      },
    );

    test('model.delete() does NOT call adapter.delete()', () async {
      final adapter = await _softUserAdapter();
      final tracker = _DeleteCallCounter(adapter);
      final ctx = _softUserContext(tracker);
      final user = await QueryBuilder<_SoftUser>.from(
        ctx,
      ).where(const ComparableField<int>('id').eq(1)).first();
      await user!.delete();
      expect(tracker.deleteCalls, 0);
    });

    test('User.query() returns only live rows after soft-delete', () async {
      final adapter = await _softUserAdapter();
      final ctx = _softUserContext(adapter);
      final user = await QueryBuilder<_SoftUser>.from(
        ctx,
      ).where(const ComparableField<int>('id').eq(1)).first();
      await user!.delete();

      final live = await QueryBuilder<_SoftUser>.from(ctx).get();
      expect(live, hasLength(1));
      expect(live.first.userId, 2);
    });

    test(
      'model.restore() clears deleted_at and model reappears in queries',
      () async {
        final adapter = await _softUserAdapter();
        final ctx = _softUserContext(adapter);
        final user = await QueryBuilder<_SoftUser>.from(
          ctx,
        ).where(const ComparableField<int>('id').eq(1)).first();
        await user!.delete();

        var live = await QueryBuilder<_SoftUser>.from(ctx).get();
        expect(live.map((u) => u.userId), isNot(contains(1)));

        await user.restore();
        expect(user.deletedAt, isNull);

        live = await QueryBuilder<_SoftUser>.from(ctx).get();
        expect(live.map((u) => u.userId), contains(1));
      },
    );

    test(
      'model.forceDelete() removes the row even from withTrashed() results',
      () async {
        final adapter = await _softUserAdapter();
        final ctx = _softUserContext(adapter);
        final user = await QueryBuilder<_SoftUser>.from(
          ctx,
        ).where(const ComparableField<int>('id').eq(1)).first();
        await user!.forceDelete();

        final all = await QueryBuilder<_SoftUser>.from(ctx).withTrashed().get();
        expect(all.map((u) => u.userId), isNot(contains(1)));
        expect(all, hasLength(1));
      },
    );
  });

  group('SoftDeletes restore lifecycle', () {
    test('restore fires beforeRestore then afterRestore', () async {
      final adapter = await _softUserAdapter();
      final user = _HookedSoftUser(adapter: adapter);
      final ok = await user.restore();
      expect(ok, isTrue);
      expect(user.events, <String>['beforeRestore', 'afterRestore']);
      expect(user.deletedAt, isNull);
    });

    test('a canceling beforeRestore aborts the restore', () async {
      final adapter = await _softUserAdapter();
      final user = _HookedSoftUser(adapter: adapter, cancelRestore: true);
      final ok = await user.restore();
      expect(ok, isFalse);
      expect(user.events, <String>['beforeRestore']);
      expect(user.deletedAt, isNotNull);
    });
  });
}

/// Adapter wrapper that counts `delete()` invocations.
///
/// Used to assert that `SoftDeletes.delete()` never
/// routes through `adapter.delete()` (AC: soft delete
/// is an UPDATE, not a hard delete).
final class _DeleteCallCounter extends DatabaseAdapter {
  _DeleteCallCounter(this._inner) : super(capabilities: _inner.capabilities);

  final DatabaseAdapter _inner;
  int deleteCalls = 0;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor) =>
      _inner.select(descriptor);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor) =>
      _inner.selectOne(descriptor);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor descriptor) =>
      _inner.insert(descriptor);

  @override
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor descriptor,
  ) => _inner.insertMany(descriptor);

  @override
  Future<int> update(UpdateDescriptor descriptor) => _inner.update(descriptor);

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

// adapter_capabilities import kept reachable when the
// inner adapter forwards capabilities — flag for the
// import_sorter without referencing the class directly.
// ignore: unused_element
const _ = AdapterCapabilities;
