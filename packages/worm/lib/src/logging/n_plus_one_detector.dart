/// N+1 query-pattern detector.
library;

/// Detects N+1 patterns by counting same-table query records inside
/// a sliding wall-clock window.
///
/// The detector is stateful but per-instance and per-table; it has
/// no global state and can be safely constructed per request /
/// per test. Calls to [recordQuery] append a timestamp from an
/// injected clock; calls to [shouldWarn] evict timestamps older
/// than the window before comparing against the threshold, so
/// memory does not grow without bound.
///
/// Warnings only — the detector never throws.
final class NPlusOneDetector {
  /// Creates a detector with the given defaults.
  ///
  /// [clock] defaults to [DateTime.now]; tests inject a controllable
  /// clock to verify stale-entry eviction deterministically.
  NPlusOneDetector({
    this.threshold = 5,
    this.window = const Duration(milliseconds: 100),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Default minimum same-table record count that triggers a
  /// warning. Per-call overrides are accepted by [shouldWarn].
  final int threshold;

  /// Default sliding-window duration. Per-call overrides are
  /// accepted by [shouldWarn].
  final Duration window;

  final DateTime Function() _clock;
  final Map<String, List<DateTime>> _queryLog = <String, List<DateTime>>{};

  /// Record one query against [table] at the current clock time.
  void recordQuery(String table) {
    _queryLog.putIfAbsent(table, () => <DateTime>[]).add(_clock());
  }

  /// Returns `true` when [table] has been queried at least
  /// [threshold] times within [window]. Stale entries are evicted
  /// from the internal log as a side-effect so subsequent calls do
  /// not pay for old observations.
  bool shouldWarn(String table, {int? threshold, Duration? window}) {
    final t = threshold ?? this.threshold;
    final w = window ?? this.window;
    final entries = _queryLog[table];
    if (entries == null) return false;
    _evictBefore(entries, _clock().subtract(w));
    if (entries.isEmpty) _queryLog.remove(table);
    return entries.length >= t;
  }

  /// Forget every observation for [table]. Use after firing to
  /// avoid spamming the same warning back-to-back.
  void resetTable(String table) => _queryLog.remove(table);

  /// Forget every observation across all tables.
  void reset() => _queryLog.clear();

  void _evictBefore(List<DateTime> entries, DateTime cutoff) {
    entries.removeWhere((t) => t.isBefore(cutoff));
  }
}
