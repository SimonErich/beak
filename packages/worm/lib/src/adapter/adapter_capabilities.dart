/// Declarative feature matrix for database adapters.
library;

/// Declares which features a `DatabaseAdapter` supports.
///
/// The query builder and adapter base class consult these flags
/// before invoking adapter operations. All flags default to `false`
/// so adapters explicitly opt **in** to the features they can
/// fulfil.
///
/// This type only describes capability. Enforcement — throwing when
/// a caller invokes an operation the adapter does not support — is
/// the adapter's responsibility. [supports] is a safe existence
/// check and never throws.
final class AdapterCapabilities {
  /// Creates an [AdapterCapabilities] descriptor.
  const AdapterCapabilities({
    this.supportsTransactions = false,
    this.supportsSavepoints = false,
    this.supportsStreaming = false,
    this.supportsRawQuery = false,
    this.supportsReturning = false,
    this.supportsJoins = false,
    this.supportsPreparedStatements = false,
    this.supportsPartialIndexes = false,
    this.supportsAggregations = false,
    this.supportsSchemaIntrospection = false,
    this.supportsExplain = false,
  });

  /// Whether the adapter supports transactions.
  final bool supportsTransactions;

  /// Whether the adapter supports nested savepoints within a
  /// transaction.
  final bool supportsSavepoints;

  /// Whether the adapter supports streaming reads (cursor-based
  /// iteration).
  final bool supportsStreaming;

  /// Whether raw / native query pass-through is supported.
  final bool supportsRawQuery;

  /// Whether `RETURNING`-style clauses are supported on writes.
  final bool supportsReturning;

  /// Whether the adapter supports joins.
  final bool supportsJoins;

  /// Whether prepared statement caching is supported.
  final bool supportsPreparedStatements;

  /// Whether partial (filtered) indexes are supported.
  final bool supportsPartialIndexes;

  /// Whether aggregate functions are supported.
  final bool supportsAggregations;

  /// Whether schema introspection is supported.
  final bool supportsSchemaIntrospection;

  /// Whether the adapter can render an `EXPLAIN` plan for a
  /// `QueryDescriptor` via `DatabaseAdapter.explain`. Gates the
  /// `MissingIndexWarner` from emitting warnings against adapters
  /// that cannot produce a plan.
  final bool supportsExplain;

  /// Safe existence check for a named capability.
  ///
  /// Returns the matching flag for recognised keys and `false` for
  /// any unknown key. Never throws — callers use this to query
  /// availability, not to gate execution.
  bool supports(String capability) => switch (capability) {
    'transactions' => supportsTransactions,
    'savepoints' => supportsSavepoints,
    'streaming' => supportsStreaming,
    'rawQuery' => supportsRawQuery,
    'returning' => supportsReturning,
    'joins' => supportsJoins,
    'preparedStatements' => supportsPreparedStatements,
    'partialIndexes' => supportsPartialIndexes,
    'aggregations' => supportsAggregations,
    'schemaIntrospection' => supportsSchemaIntrospection,
    'explain' => supportsExplain,
    _ => false,
  };

  /// Returns a copy of these capabilities with overridden flags.
  AdapterCapabilities copyWith({
    bool? supportsTransactions,
    bool? supportsSavepoints,
    bool? supportsStreaming,
    bool? supportsRawQuery,
    bool? supportsReturning,
    bool? supportsJoins,
    bool? supportsPreparedStatements,
    bool? supportsPartialIndexes,
    bool? supportsAggregations,
    bool? supportsSchemaIntrospection,
    bool? supportsExplain,
  }) => AdapterCapabilities(
    supportsTransactions: supportsTransactions ?? this.supportsTransactions,
    supportsSavepoints: supportsSavepoints ?? this.supportsSavepoints,
    supportsStreaming: supportsStreaming ?? this.supportsStreaming,
    supportsRawQuery: supportsRawQuery ?? this.supportsRawQuery,
    supportsReturning: supportsReturning ?? this.supportsReturning,
    supportsJoins: supportsJoins ?? this.supportsJoins,
    supportsPreparedStatements:
        supportsPreparedStatements ?? this.supportsPreparedStatements,
    supportsPartialIndexes:
        supportsPartialIndexes ?? this.supportsPartialIndexes,
    supportsAggregations: supportsAggregations ?? this.supportsAggregations,
    supportsSchemaIntrospection:
        supportsSchemaIntrospection ?? this.supportsSchemaIntrospection,
    supportsExplain: supportsExplain ?? this.supportsExplain,
  );
}
