/// Strictness flags for the worm ORM runtime.
library;

/// Independently toggleable strictness flags.
///
/// Each flag controls a single safety check. Flags
/// are orthogonal — flipping one never implicitly
/// flips another. All flags default to `false`;
/// production deployments typically enable them all.
final class StrictnessConfig {
  /// Creates a [StrictnessConfig].
  const StrictnessConfig({
    this.preventLazyLoading = false,
    this.preventFullTableScans = false,
    this.preventSilentMassAssignment = false,
    this.warnOnN1Queries = false,
    this.throwOnN1Queries = false,
    this.warnOnMissingIndex = false,
    this.preventDestructiveWithoutWhere = false,
    this.slowQueryThreshold = const Duration(milliseconds: 500),
  });

  /// Throw when an unloaded relation is accessed.
  final bool preventLazyLoading;

  /// Throw when a query would scan the whole table.
  final bool preventFullTableScans;

  /// Throw when mass assignment silently drops
  /// guarded fields.
  final bool preventSilentMassAssignment;

  /// Warn when an N+1 query pattern is detected.
  ///
  /// Aliased as `warnOnNPlusOne` in spec terminology.
  final bool warnOnN1Queries;

  /// Escalate detected N+1 patterns from a warning to a thrown
  /// [`DangerousQueryException`].
  ///
  /// When `true`, [`LoggingAdapter`] aborts the offending query with
  /// a typed exception carrying the offending table name; when
  /// `false` (the default) detected patterns only log a `[WARNING]`
  /// line provided [warnOnN1Queries] is also `true`. The two flags
  /// are orthogonal — strict deployments typically enable both, while
  /// perf-benchmark suites should leave this `false` because bulk
  /// writes can look like N+1 patterns to the detector.
  final bool throwOnN1Queries;

  /// Warn when an EXPLAIN plan indicates a query is not using an
  /// index for its predicates.
  final bool warnOnMissingIndex;

  /// Throw on `UPDATE` or `DELETE` without a `WHERE` clause.
  final bool preventDestructiveWithoutWhere;

  /// Queries exceeding this duration trigger a slow-query warning.
  final Duration slowQueryThreshold;

  /// Returns a copy of this config with selected flags overridden.
  StrictnessConfig copyWith({
    bool? preventLazyLoading,
    bool? preventFullTableScans,
    bool? preventSilentMassAssignment,
    bool? warnOnN1Queries,
    bool? throwOnN1Queries,
    bool? warnOnMissingIndex,
    bool? preventDestructiveWithoutWhere,
    Duration? slowQueryThreshold,
  }) => StrictnessConfig(
    preventLazyLoading: preventLazyLoading ?? this.preventLazyLoading,
    preventFullTableScans: preventFullTableScans ?? this.preventFullTableScans,
    preventSilentMassAssignment:
        preventSilentMassAssignment ?? this.preventSilentMassAssignment,
    warnOnN1Queries: warnOnN1Queries ?? this.warnOnN1Queries,
    throwOnN1Queries: throwOnN1Queries ?? this.throwOnN1Queries,
    warnOnMissingIndex: warnOnMissingIndex ?? this.warnOnMissingIndex,
    preventDestructiveWithoutWhere:
        preventDestructiveWithoutWhere ?? this.preventDestructiveWithoutWhere,
    slowQueryThreshold: slowQueryThreshold ?? this.slowQueryThreshold,
  );
}
