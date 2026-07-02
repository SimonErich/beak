/// LRU cache for PostgreSQL prepared statements.
library;

import 'dart:collection';

/// A bounded LRU cache keyed by SQL string.
///
/// Used by the Postgres adapter to avoid re-preparing statements
/// inside a hot loop of executions. Eviction is strict
/// least-recently-used: the entry at the front of the internal
/// [LinkedHashMap] (oldest access) is dropped when a new entry is
/// inserted at capacity.
///
/// The cache is a pure, in-memory data structure with no I/O — it
/// never prepares statements itself. Callers invoke [get] first to
/// check for a cached value, fall back to preparing a fresh
/// statement on a miss, then hand the prepared statement to [put].
///
/// Hit- and miss-counters back [missRate] for diagnostics. They are
/// reset alongside the cache by [clear].
final class PreparedStatementCache<V extends Object> {
  /// Creates an empty cache holding at most [maxSize] entries.
  PreparedStatementCache({this.maxSize = 100})
    : assert(maxSize > 0, 'maxSize must be > 0'),
      _cache = LinkedHashMap<String, V>();

  /// Maximum number of entries retained at any one time. Adding a
  /// new SQL string when the cache is full evicts the
  /// least-recently-used entry.
  final int maxSize;

  final LinkedHashMap<String, V> _cache;

  int _hitCount = 0;
  int _missCount = 0;

  /// Number of [get] calls that returned a cached value.
  int get hitCount => _hitCount;

  /// Number of [get] calls that returned `null`.
  int get missCount => _missCount;

  /// Current number of cached entries.
  int get length => _cache.length;

  /// Ratio of misses to total [get] calls.
  ///
  /// Returns `0.0` when no [get] calls have been made — a cold
  /// cache is defined to have zero miss rate until the first
  /// access.
  double get missRate {
    final total = _hitCount + _missCount;
    if (total == 0) return 0.0;
    return _missCount / total;
  }

  /// Returns the cached value for [sql], or `null` on a miss.
  ///
  /// A hit promotes the entry to most-recently-used and increments
  /// [hitCount]; a miss increments [missCount] and leaves the
  /// cache unchanged.
  V? get(String sql) {
    final existing = _cache.remove(sql);
    if (existing == null) {
      _missCount++;
      return null;
    }
    _cache[sql] = existing;
    _hitCount++;
    return existing;
  }

  /// Stores [value] under [sql], promoting it to MRU.
  ///
  /// If [sql] is already present, its previous entry is replaced
  /// and re-positioned at MRU. Otherwise, when [length] has reached
  /// [maxSize], the LRU entry is evicted first.
  void put(String sql, V value) {
    if (_cache.remove(sql) == null && _cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[sql] = value;
  }

  /// Whether [sql] has a cached value. Does not affect LRU order
  /// or counters.
  bool contains(String sql) => _cache.containsKey(sql);

  /// Removes every cached entry and resets [hitCount] and
  /// [missCount] to zero.
  void clear() {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
  }
}
