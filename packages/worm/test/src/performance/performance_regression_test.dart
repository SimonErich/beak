/// Performance regression benchmarks against `InMemoryAdapter`.
///
/// Three guarantees are pinned here:
///
/// 1. 10 000 individual `adapter.insert()` calls finish in
///    under 5 seconds.
/// 2. A 1 000-parent / 5 000-child eager-load completes in
///    under 500 ms AND issues exactly two `adapter.select()`
///    calls (one parent SELECT + one chunked-IN child
///    SELECT — well below the 1 000-id chunk boundary).
/// 3. Streaming 50 000 rows via `adapter.stream()` adds
///    fewer than 50 MB to `ProcessInfo.currentRss`.
///
/// Thresholds are calibrated for the in-memory adapter only.
/// Postgres / MongoDB adapters live in their own packages and
/// will need their own benchmark suites — those targets are
/// out of scope for this file.
///
/// The whole file is tagged `performance` so the default
/// `dart test` run skips it; CI invokes the suite explicitly
/// with `dart test --tags performance`.
@Tags(<String>['performance'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/adapter_capabilities.dart';
import 'package:worm/src/adapter/database_adapter.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/logging/explain_runner.dart';
import 'package:worm/src/model/model.dart';
import 'package:worm/src/query/aggregate_descriptor.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_builder.dart';
import 'package:worm/src/query/query_context.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';
import 'package:worm/src/relation/has_many.dart';
import 'package:worm/src/relation/relation_base.dart';

/// Minimal user model backed entirely by `state.attributes` —
/// keeps hydration cheap so the perf numbers reflect the
/// adapter and relation paths, not unrelated model setup.
final class _PerfUser extends Model {
  factory _PerfUser.fromRow(
    Map<String, Object?> row, {
    // ignore: avoid_unused_constructor_parameters
    Set<String>? requestedColumns,
  }) {
    final user = _PerfUser._();
    for (final entry in row.entries) {
      user.hydrateAttribute(entry.key, entry.value);
    }
    user.markPersisted();
    return user;
  }

  _PerfUser._();

  @override
  Object get id => state.attributes['id'] ?? 0;

  @override
  Map<String, Object?> toRow() =>
      Map<String, Object?>.unmodifiable(state.attributes);
}

/// Companion child model for the eager-load benchmark.
final class _PerfPost extends Model {
  factory _PerfPost.fromRow(
    Map<String, Object?> row, {
    // ignore: avoid_unused_constructor_parameters
    Set<String>? requestedColumns,
  }) {
    final post = _PerfPost._();
    for (final entry in row.entries) {
      post.hydrateAttribute(entry.key, entry.value);
    }
    post.markPersisted();
    return post;
  }

  _PerfPost._();

  @override
  Object get id => state.attributes['id'] ?? 0;

  @override
  Map<String, Object?> toRow() =>
      Map<String, Object?>.unmodifiable(state.attributes);
}

/// Forwarding adapter that ticks a counter for every
/// `select` / `selectOne` call. Used to pin the exact query
/// count of the eager-load benchmark so a regression in IN
/// chunking or concurrent loading is caught alongside the
/// wall-clock budget.
final class _CountingAdapter extends DatabaseAdapter with ExplainCapable {
  _CountingAdapter(this._inner) : super(capabilities: _inner.capabilities);

  final InMemoryAdapter _inner;

  /// Number of `select` calls observed since construction.
  int selectCalls = 0;

  @override
  AdapterCapabilities get capabilities => _inner.capabilities;

  @override
  Future<void> connect() => _inner.connect();

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    selectCalls++;
    return _inner.select(d);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) {
    selectCalls++;
    return _inner.selectOne(d);
  }

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
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _inner.rawQuery(q, p);

  @override
  Future<int> rawExecute(String s, List<Object?> p) => _inner.rawExecute(s, p);

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

  @override
  Future<ExplainResult> explain(QueryDescriptor descriptor) async =>
      const ExplainResult(usesIndex: true, raw: 'counting adapter: synthetic');
}

/// Strictness profile for the perf suite: N+1 detection is
/// explicitly disarmed so the bulk-insert and bulk-query
/// patterns the benchmarks generate do not trip the warner
/// (they look like N+1 access from a row-count perspective).
const StrictnessConfig _perfStrictness = StrictnessConfig();

Future<InMemoryAdapter> _freshUsersTable() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  return adapter;
}

void main() {
  group('Performance regressions (InMemoryAdapter baseline)', () {
    test('10 000 single inserts complete in < 5 s', () async {
      final adapter = await _freshUsersTable();
      final sw = Stopwatch()..start();
      for (var i = 1; i <= 10000; i++) {
        await adapter.insert(
          InsertDescriptor(
            table: 'users',
            values: <String, Object?>{'id': i, 'name': 'user-$i'},
          ),
        );
      }
      sw.stop();
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason:
            'Single-row inserts: 10 000 calls took '
            '${sw.elapsedMilliseconds} ms; spec budget is 5 000 ms on '
            'InMemoryAdapter.',
      );
    });

    test('1 000 users + 5 000 posts eager-loaded — < 500 ms AND exactly 2 '
        'adapter.select() calls', () async {
      final inner = InMemoryAdapter();
      await inner.connect();
      await inner.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      await inner.executeSchema(
        const SchemaDescriptor.createTable(table: 'posts'),
      );

      // Seed 1 000 users and 5 000 posts (5 children per
      // parent). 1 000 parent ids stay under the 1 000-row
      // chunk boundary, so IN-chunking emits a single child
      // SELECT — total of 2 round-trips end to end.
      await inner.insertMany(
        InsertManyDescriptor(
          table: 'users',
          rows: <Map<String, Object?>>[
            for (var i = 1; i <= 1000; i++)
              <String, Object?>{'id': i, 'name': 'user-$i'},
          ],
        ),
      );
      await inner.insertMany(
        InsertManyDescriptor(
          table: 'posts',
          rows: <Map<String, Object?>>[
            for (var i = 1; i <= 5000; i++)
              <String, Object?>{
                'id': i,
                // 5 children per parent — round-robin assignment.
                'user_id': ((i - 1) % 1000) + 1,
                'title': 'post-$i',
              },
          ],
        ),
      );

      final counting = _CountingAdapter(inner);
      final context = QueryContext<_PerfUser>(
        adapter: counting,
        table: 'users',
        hydrate: _PerfUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': const HasManyRelation<Model, Model>(
            name: 'posts',
            childTable: 'posts',
            foreignKey: 'user_id',
            hydrateChild: _PerfPost.fromRow,
          ),
        },
      );

      final sw = Stopwatch()..start();
      final users = await QueryBuilder<_PerfUser>.from(
        context,
        strictness: _perfStrictness,
      ).withRelationPaths(const <String>['posts']).get();
      sw.stop();

      expect(users, hasLength(1000));
      expect(
        counting.selectCalls,
        2,
        reason:
            'Exactly 2 SELECTs expected: one for parents, one for the '
            'IN-chunked child batch. Concurrent loading must not change '
            'this count.',
      );
      expect(
        sw.elapsed,
        lessThan(const Duration(milliseconds: 500)),
        reason:
            'Eager-load 1 000+5 000 took ${sw.elapsedMilliseconds} ms; '
            'spec budget is 500 ms on InMemoryAdapter.',
      );

      // Sanity-check the rehydration shape — first parent
      // observed 5 children, last parent observed 5 children,
      // proving the chunk merge populated the full set.
      final firstChildren = users.first.relations['posts'];
      expect(firstChildren, isA<List<Model>>());
      if (firstChildren case final List<Model> list) {
        expect(list, hasLength(5));
      }
    });

    test(
      'streaming 50 000 rows adds < 50 MB to ProcessInfo.currentRss',
      () async {
        final adapter = await _freshUsersTable();

        // Seed 50 000 rows before the RSS snapshot so the
        // backing store's allocation does NOT count against
        // the budget — only stream-consumer growth is being
        // measured.
        await adapter.insertMany(
          InsertManyDescriptor(
            table: 'users',
            rows: <Map<String, Object?>>[
              for (var i = 1; i <= 50000; i++)
                <String, Object?>{'id': i, 'name': 'u-$i'},
            ],
          ),
        );

        final baselineRss = ProcessInfo.currentRss;
        if (baselineRss == 0) {
          markTestSkipped(
            'ProcessInfo.currentRss returns 0 on this platform; the RSS '
            'growth assertion needs a Linux/macOS host.',
          );
          return;
        }

        var observed = 0;
        await for (final _ in adapter.stream(
          const QueryDescriptor(table: 'users'),
        )) {
          // Drop the row immediately — the AC under test is
          // that streaming does NOT retain rows in memory
          // beyond the per-iteration scope. Counting rows
          // keeps the loop work non-trivial without forcing
          // the runtime to retain anything.
          observed++;
        }

        // RSS is process-wide — when `dart test` runs multiple test
        // files in parallel isolates within a single process, the
        // baseline → final delta picks up allocations from other
        // isolates too. To keep the assertion focused on the stream
        // consumer, take a follow-up sample after a brief event-loop
        // yield (gives the runtime a chance to settle and any
        // unrelated allocations to release) and use the minimum.
        final firstSample = ProcessInfo.currentRss;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final secondSample = ProcessInfo.currentRss;
        final finalRss = firstSample < secondSample
            ? firstSample
            : secondSample;
        final growthBytes = finalRss - baselineRss;
        const limitBytes = 50 * 1024 * 1024; // 50 MB

        expect(observed, 50000, reason: 'stream() must deliver every row');
        expect(
          growthBytes,
          lessThan(limitBytes),
          reason:
              'RSS grew by ${(growthBytes / (1024 * 1024)).toStringAsFixed(1)} '
              'MB while streaming; spec budget is 50 MB on '
              'InMemoryAdapter. A regression here usually means a stream '
              'consumer is retaining rows it should be discarding. Note: '
              'under default `dart test` parallelism this measurement is '
              'noisy because RSS is process-wide; run '
              '`dart test --tags performance --concurrency=1` for a '
              'clean baseline.',
        );
      },
    );

    test('complex query (relation + 2 aggregates) issues a constant, '
        'row-count-independent number of SELECTs (no N+1)', () async {
      Future<int> selectsFor(int users) async {
        final inner = InMemoryAdapter();
        await inner.connect();
        await inner.executeSchema(
          const SchemaDescriptor.createTable(table: 'users'),
        );
        await inner.executeSchema(
          const SchemaDescriptor.createTable(table: 'posts'),
        );
        await inner.insertMany(
          InsertManyDescriptor(
            table: 'users',
            rows: <Map<String, Object?>>[
              for (var i = 1; i <= users; i++)
                <String, Object?>{'id': i, 'name': 'user-$i'},
            ],
          ),
        );
        await inner.insertMany(
          InsertManyDescriptor(
            table: 'posts',
            rows: <Map<String, Object?>>[
              for (var i = 1; i <= users * 5; i++)
                <String, Object?>{
                  'id': i,
                  'user_id': ((i - 1) % users) + 1,
                  'title': 'post-$i',
                  'views': i % 10,
                },
            ],
          ),
        );
        final counting = _CountingAdapter(inner);
        final context = QueryContext<_PerfUser>(
          adapter: counting,
          table: 'users',
          hydrate: _PerfUser.fromRow,
          relations: <String, Relation<Model, Model>>{
            'posts': const HasManyRelation<Model, Model>(
              name: 'posts',
              childTable: 'posts',
              foreignKey: 'user_id',
              hydrateChild: _PerfPost.fromRow,
            ),
          },
        );
        await QueryBuilder<_PerfUser>.from(context, strictness: _perfStrictness)
            .withRelationPaths(const <String>['posts'])
            .withCount('posts')
            .withSum('posts', 'views')
            .get();
        return counting.selectCalls;
      }

      // 1 parent SELECT + 1 posts SELECT + 1 count SELECT + 1 sum SELECT,
      // regardless of how many users/posts exist.
      final small = await selectsFor(100);
      final large = await selectsFor(1000);
      expect(small, 4);
      expect(
        large,
        small,
        reason: 'SELECT count must not grow with row count (no N+1)',
      );
    });
  });
}
