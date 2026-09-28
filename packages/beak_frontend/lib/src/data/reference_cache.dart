import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../auth/beak_auth_adapter.dart';

import 'beak_data_changes.dart';

/// Coalesces reference lookups into batched fetches and caches the results
/// — many cells resolving the same or sibling references within a frame
/// cost one `batchGet` per table, never N `getOne`s.
///
/// Registered as a singleton by [registerBeakDependencies]; table cells
/// rendering a foreign key (e.g. a product's category name) call [resolve]
/// and the cache batches every request made in the same microtask window
/// into one round-trip. After a mutation, [invalidate] the touched id (or
/// [invalidateTable]) so the next resolve refetches.
///
/// ```dart
/// final category = await referenceCache.resolve('categories', categoryId);
/// // ...after editing that category:
/// referenceCache.invalidate('categories', categoryId);
/// ```
final class ReferenceCache {
  /// Creates a cache resolving through [dataSource], using [registry] for
  /// primary-key metadata.
  ReferenceCache(this.dataSource, this.registry, {BeakAuthAdapter? auth}) {
    if (auth != null) {
      _authCleanup = effect(() {
        auth.state.value;
        invalidateAll();
      });
    }
    if (dataSource case final BeakMutationSource source) {
      _changes = source.changes.listen((change) {
        for (final table in change.tables) {
          invalidateTable(table);
        }
      });
    }
  }

  /// The source batched fetches run against.
  final BeakDataSource dataSource;

  /// The models whose primary keys identify cached records.
  final BeakModelRegistry registry;

  final Map<String, Map<Object, BeakRecord>> _recordsByTable = {};
  final Map<String, int> _versions = {};
  StreamSubscription<BeakDataChange>? _changes;
  bool _disposed = false;
  int _scopeVersion = 0;
  void Function()? _authCleanup;
  final Set<Map<Object, Completer<BeakRecord>>> _activeBatches = {};

  /// Releases automatic invalidation and drops cached records.
  Future<void> dispose() async {
    _disposed = true;
    _authCleanup?.call();
    invalidateAll();
    await _changes?.cancel();
  }

  final Map<String, Map<Object, Completer<BeakRecord>>> _pendingByTable = {};

  /// Resolves the record of [table] with primary key [id].
  ///
  /// Calls arriving within the same microtask window coalesce into one
  /// `batchGet`; resolved records are cached until [invalidate]. A missing
  /// id fails with a `BeakNotFoundException`.
  Future<BeakRecord> resolve(String table, Object id) {
    if (_disposed) {
      return Future.error(
        const BeakConfigurationException('Reference cache is disposed.'),
      );
    }
    final cached = _recordsByTable[table]?[id];
    if (cached != null) {
      return Future.value(cached);
    }
    final pending = _pendingByTable.putIfAbsent(table, () => {});
    final existing = pending[id];
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<BeakRecord>();
    pending[id] = completer;
    if (pending.length == 1) {
      scheduleMicrotask(() => _flush(table));
    }
    return completer.future;
  }

  /// Drops the cached record of [table] with [id] so the next resolve
  /// refetches it.
  void invalidate(String table, Object id) {
    _recordsByTable[table]?.remove(id);
    _versions[table] = (_versions[table] ?? 0) + 1;
  }

  /// Drops every cached record of [table].
  void invalidateTable(String table) {
    _recordsByTable.remove(table);
    _versions[table] = (_versions[table] ?? 0) + 1;
  }

  /// Drops all records and cancels lookups from the previous authentication
  /// scope. Late responses cannot publish data into the replacement scope.
  void invalidateAll() {
    _scopeVersion++;
    _recordsByTable.clear();
    final pending = {..._activeBatches, ..._pendingByTable.values};
    _pendingByTable.clear();
    _activeBatches.clear();
    for (final batch in pending) {
      for (final completer in batch.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const BeakAuthenticationException(
              'The reference lookup session changed.',
            ),
          );
        }
      }
    }
  }

  Future<void> _flush(String table) async {
    final pending = _pendingByTable.remove(table);
    if (pending == null || pending.isEmpty) {
      return;
    }
    final scopeVersion = _scopeVersion;
    _activeBatches.add(pending);
    try {
      final String primaryKeyColumn = registry
          .byTableOrThrow(table)
          .primaryKey
          .key;
      var version = _versions[table] ?? 0;
      var records = await dataSource.batchGet(table, pending.keys.toList());
      while (!_disposed &&
          scopeVersion == _scopeVersion &&
          version != (_versions[table] ?? 0)) {
        version = _versions[table] ?? 0;
        records = await dataSource.batchGet(table, pending.keys.toList());
      }
      if (_disposed || scopeVersion != _scopeVersion) return;
      final cache = _recordsByTable.putIfAbsent(table, () => {});
      for (final record in records) {
        final Object? id = record[primaryKeyColumn]?.raw;
        if (id != null) {
          cache[id] = record;
        }
      }
      for (final MapEntry(:key, :value) in pending.entries) {
        final record = cache[key];
        if (record != null) {
          value.complete(record);
        } else {
          value.completeError(
            BeakNotFoundException('No record of "$table" with id "$key".'),
            StackTrace.current,
          );
        }
      }
    } on Object catch (error, stackTrace) {
      for (final completer in pending.values) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    } finally {
      _activeBatches.remove(pending);
    }
  }
}
