import 'dart:async';

import 'package:beak_core/beak_core.dart';

/// Coalesces reference lookups into batched fetches and caches the results
/// — many cells resolving the same or sibling references within a frame
/// cost one `batchGet` per table, never N `getOne`s.
final class ReferenceCache {
  /// Creates a cache resolving through [dataSource], using [registry] for
  /// primary-key metadata.
  ReferenceCache(this.dataSource, this.registry);

  /// The source batched fetches run against.
  final BeakDataSource dataSource;

  /// The models whose primary keys identify cached records.
  final BeakModelRegistry registry;

  final Map<String, Map<Object, BeakRecord>> _recordsByTable = {};
  final Map<String, Map<Object, Completer<BeakRecord>>> _pendingByTable = {};

  /// Resolves the record of [table] with primary key [id].
  ///
  /// Calls arriving within the same microtask window coalesce into one
  /// `batchGet`; resolved records are cached until [invalidate]. A missing
  /// id fails with a `BeakNotFoundException`.
  Future<BeakRecord> resolve(String table, Object id) {
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
  }

  /// Drops every cached record of [table].
  void invalidateTable(String table) {
    _recordsByTable.remove(table);
  }

  Future<void> _flush(String table) async {
    final pending = _pendingByTable.remove(table);
    if (pending == null || pending.isEmpty) {
      return;
    }
    final String primaryKeyColumn = registry
        .byTableOrThrow(table)
        .primaryKey
        .key;
    try {
      final records = await dataSource.batchGet(table, pending.keys.toList());
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
        completer.completeError(error, stackTrace);
      }
    }
  }
}
