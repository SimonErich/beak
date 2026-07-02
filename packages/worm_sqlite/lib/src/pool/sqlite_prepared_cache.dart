/// Bounded LRU cache of compiled SQLite prepared statements.
library;

import 'dart:collection';

import 'package:sqlite3/common.dart';

/// Caches [CommonPreparedStatement]s keyed by their SQL text so a hot
/// loop of identical queries compiles each statement once.
///
/// Eviction is strict least-recently-used: the oldest-accessed entry
/// is disposed when a new statement is prepared at capacity. The cache
/// owns the statements it holds and disposes them on eviction and on
/// [clear]. Hit / miss counters back [missRate] for diagnostics.
///
/// Statements are bound to the database connection, so the cache must
/// be cleared on schema changes (a recreated table can invalidate a
/// statement that referenced it) — the adapter does this on DDL.
final class SqlitePreparedCache {
  /// Creates a cache over `database` holding at most [maxSize]
  /// statements.
  SqlitePreparedCache(this._database, {this.maxSize = 128})
    : assert(maxSize > 0, 'maxSize must be > 0');

  final CommonDatabase _database;

  /// Maximum number of prepared statements retained at once.
  final int maxSize;

  final LinkedHashMap<String, CommonPreparedStatement> _cache =
      LinkedHashMap<String, CommonPreparedStatement>();

  int _hitCount = 0;
  int _missCount = 0;

  /// Number of lookups served from the cache.
  int get hitCount => _hitCount;

  /// Number of lookups that had to prepare a fresh statement.
  int get missCount => _missCount;

  /// Current number of cached statements.
  int get length => _cache.length;

  /// Ratio of misses to total lookups; `0.0` for a cold cache.
  double get missRate {
    final total = _hitCount + _missCount;
    if (total == 0) return 0;
    return _missCount / total;
  }

  /// Returns the prepared statement for [sql], compiling and caching it
  /// on a miss (evicting and disposing the LRU entry at capacity), and
  /// promoting it to most-recently-used.
  CommonPreparedStatement statementFor(String sql) {
    final existing = _cache.remove(sql);
    if (existing != null) {
      _cache[sql] = existing;
      _hitCount++;
      return existing;
    }
    _missCount++;
    if (_cache.length >= maxSize) {
      final evicted = _cache.remove(_cache.keys.first);
      evicted?.dispose();
    }
    final statement = _database.prepare(sql);
    _cache[sql] = statement;
    return statement;
  }

  /// Dispose and drop every cached statement, resetting counters.
  ///
  /// Called on schema changes (statements may reference altered
  /// tables) and when the connection closes.
  void clear() {
    for (final statement in _cache.values) {
      statement.dispose();
    }
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
  }
}
