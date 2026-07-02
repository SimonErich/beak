/// Streaming terminals deliver rows in bounded-memory
/// batches against the InMemoryAdapter.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/exception/configuration_exception.dart';
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
import 'package:worm/src/scope/soft_delete_scope.dart';

import '_fixtures.dart';

Future<InMemoryAdapter> _adapterWithRows(int rows) async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  if (rows == 0) return adapter;
  await adapter.insertMany(
    InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        for (var i = 1; i <= rows; i++)
          <String, Object?>{
            'id': i,
            'name': 'User$i',
            'age': 20 + (i % 50),
            'deleted_at': null,
          },
      ],
    ),
  );
  return adapter;
}

/// Adapter wrapper that records each `stream` call so
/// tests can prove `stream()` is invoked exactly once.
final class _RecordingAdapter extends DatabaseAdapter {
  _RecordingAdapter(this._inner);

  final InMemoryAdapter _inner;

  /// Each entry is the descriptor table for a `stream`
  /// invocation.
  final List<String> streamCalls = <String>[];

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _inner.select(d);

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
  Future<int> count(AggregateDescriptor d) => _inner.count(d);

  @override
  Future<num?> sum(AggregateDescriptor d) => _inner.sum(d);

  @override
  Future<double?> avg(AggregateDescriptor d) => _inner.avg(d);

  @override
  Future<Object?> min(AggregateDescriptor d) => _inner.min(d);

  @override
  Future<Object?> max(AggregateDescriptor d) => _inner.max(d);

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
  Stream<Map<String, Object?>> stream(QueryDescriptor d) {
    streamCalls.add(d.table);
    return _inner.stream(d);
  }

  @override
  String compileToString(Object descriptor) =>
      _inner.compileToString(descriptor);
}

void main() {
  group('QueryBuilder streaming terminals', () {
    test('stream() yields every hydrated row exactly once', () async {
      final adapter = await _adapterWithRows(20);
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final ids = <int>[];
      await for (final user in qb.stream()) {
        ids.add(user.userId);
      }
      expect(ids, hasLength(20));
      expect(ids.toSet(), equals(<int>{for (var i = 1; i <= 20; i++) i}));
    });

    test('stream() calls adapter.stream exactly once', () async {
      final inner = await _adapterWithRows(50);
      final recording = _RecordingAdapter(inner);
      final qb = QueryBuilder<TestUser>.from(
        QueryContext<TestUser>(
          adapter: recording,
          table: 'users',
          hydrate: TestUser.fromRow,
        ),
      );
      final ids = <int>[];
      await for (final user in qb.stream()) {
        ids.add(user.userId);
      }
      expect(ids, hasLength(50));
      expect(recording.streamCalls, <String>['users']);
    });

    test(
      'chunk(500, fn) over 1500 rows invokes fn 3x with [500, 500, 500]',
      () async {
        final adapter = await _adapterWithRows(1500);
        final qb = QueryBuilder<TestUser>.from(userContext(adapter));
        final batchSizes = <int>[];
        await qb.chunk(500, (batch) async {
          batchSizes.add(batch.length);
        });
        expect(batchSizes, <int>[500, 500, 500]);
      },
    );

    test(
      'chunk(500, fn) over 1001 rows invokes fn 3x with [500, 500, 1]',
      () async {
        final adapter = await _adapterWithRows(1001);
        final qb = QueryBuilder<TestUser>.from(userContext(adapter));
        final batchSizes = <int>[];
        await qb.chunk(500, (batch) async {
          batchSizes.add(batch.length);
        });
        expect(batchSizes, <int>[500, 500, 1]);
      },
    );

    test('chunk(500, fn) over empty dataset never invokes fn', () async {
      final adapter = await _adapterWithRows(0);
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      var calls = 0;
      await qb.chunk(500, (_) async => calls++);
      expect(calls, 0);
    });

    test(
      'chunk(size, fn) called with successive lists until exhausted',
      () async {
        final adapter = await _adapterWithRows(500);
        final qb = QueryBuilder<TestUser>.from(userContext(adapter));
        final seen = <int>{};
        await qb.chunk(100, (batch) async {
          for (final user in batch) {
            seen.add(user.userId);
          }
        });
        expect(seen, hasLength(500));
      },
    );

    test('chunk(0, fn) throws ConfigurationException', () async {
      final adapter = await _adapterWithRows(1);
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      expect(
        () => qb.chunk(0, (_) async {}),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test(
      'streamChunks(500) over 1500 rows yields 3 lists of [500, 500, 500]',
      () async {
        final adapter = await _adapterWithRows(1500);
        final qb = QueryBuilder<TestUser>.from(userContext(adapter));
        final sizes = <int>[];
        await for (final batch in qb.streamChunks(500)) {
          sizes.add(batch.length);
        }
        expect(sizes, <int>[500, 500, 500]);
      },
    );

    test('streamChunks(size) emits size-bounded lists', () async {
      final adapter = await _adapterWithRows(750);
      final qb = QueryBuilder<TestUser>.from(userContext(adapter));
      final sizes = <int>[];
      await for (final batch in qb.streamChunks(200)) {
        sizes.add(batch.length);
      }
      expect(sizes, <int>[200, 200, 200, 150]);
    });

    test(
      'stream() applies soft-delete global scope, filtering trashed rows',
      () async {
        final adapter = await seededAdapter();
        final context = QueryContext<TestUser>(
          adapter: adapter,
          table: 'users',
          hydrate: TestUser.fromRow,
          globalScopes: const <SoftDeleteScope<TestUser>>[
            SoftDeleteScope<TestUser>(),
          ],
        );
        final qb = QueryBuilder<TestUser>.from(context);
        final names = <String>[];
        await for (final user in qb.stream()) {
          names.add(user.name);
        }
        // Carol is soft-deleted, the rest pass.
        expect(names.toSet(), <String>{'Alice', 'Bob', 'Dave'});
      },
    );

    test('stream() throws FullTableScanException before emitting items when '
        'preventFullTableScans is true and no WHERE is set', () async {
      final adapter = await _adapterWithRows(5);
      final qb = QueryBuilder<TestUser>.from(
        userContext(adapter),
        strictness: const StrictnessConfig(preventFullTableScans: true),
      );
      expect(() async {
        await for (final _ in qb.stream()) {
          fail('stream emitted a row before guard fired');
        }
      }, throwsA(isA<FullTableScanException>()));
    });

    test(
      'stream() with WHERE clause is permitted under preventFullTableScans',
      () async {
        final adapter = await _adapterWithRows(5);
        final qb = QueryBuilder<TestUser>.from(
          userContext(adapter),
          strictness: const StrictnessConfig(preventFullTableScans: true),
        );
        const id = ComparableField<int>('id');
        final ids = <int>[];
        await for (final user in qb.where(id.gte(1)).stream()) {
          ids.add(user.userId);
        }
        expect(ids, hasLength(5));
      },
    );
  });
}
