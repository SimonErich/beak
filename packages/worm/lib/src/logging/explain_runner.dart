/// EXPLAIN integration for adapters that expose query plans.
library;

import '../adapter/adapter_capabilities.dart';
import '../adapter/database_adapter.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import 'query_logger.dart';

/// Mix in to a `DatabaseAdapter` to expose an EXPLAIN plan.
///
/// The strictness layer probes adapters via `is ExplainCapable`. The
/// returned [ExplainResult] carries whether an index was used and a
/// raw plan string for diagnostics.
abstract mixin class ExplainCapable {
  /// Produce an [ExplainResult] for [descriptor] without executing it.
  Future<ExplainResult> explain(QueryDescriptor descriptor);
}

/// Adapter-agnostic result of an EXPLAIN run.
///
/// All fields are immutable and the type is `const`-constructible
/// so adapters that always report the same plan (e.g. the in-memory
/// adapter) can return a top-level constant.
final class ExplainResult {
  /// Creates an [ExplainResult].
  const ExplainResult({
    required this.usesIndex,
    this.raw = '',
    this.indexName,
    this.estimatedCost = 0,
    this.estimatedRows = 0,
    this.scannedTables = const <String>[],
  });

  /// Whether at least one predicate is satisfied by an index.
  final bool usesIndex;

  /// Adapter-native plan text (for diagnostics).
  final String raw;

  /// Name of the index the planner picked, when known.
  final String? indexName;

  /// Planner-estimated cost (adapter-defined unit). `0` means
  /// unknown.
  final double estimatedCost;

  /// Planner-estimated rows that will be touched. `0` means unknown.
  final int estimatedRows;

  /// Tables the plan reports a sequential / full scan against.
  final List<String> scannedTables;
}

/// Warning engine for queries whose plan does not use an index.
///
/// Stateless and `const`-constructible — instances may be shared
/// across [LoggingAdapter](`logging_adapter.dart`) instances and
/// invocations. The warner is a hard no-op unless the adapter both
/// declares `AdapterCapabilities.supportsExplain` and mixes in
/// [ExplainCapable], so callers can wire it unconditionally without
/// guarding the call site.
final class MissingIndexWarner {
  /// Creates a [MissingIndexWarner].
  const MissingIndexWarner();

  /// Inspect the plan for [descriptor] and call `logger.logWarning`
  /// when the plan reports no index use.
  ///
  /// Returns immediately (no output) when any of these is true:
  ///
  /// * `capabilities.supportsExplain` is `false`;
  /// * [adapter] does not mix in [ExplainCapable];
  /// * [descriptor] has no predicates (no columns to index);
  /// * the returned [ExplainResult.usesIndex] is `true`.
  Future<void> checkAfterQuery({
    required QueryDescriptor descriptor,
    required AdapterCapabilities capabilities,
    required DatabaseAdapter adapter,
    required QueryLogger logger,
  }) async {
    if (!capabilities.supportsExplain) return;
    final where = descriptor.where;
    if (where == null) return;
    if (adapter case final ExplainCapable explainer) {
      final result = await explainer.explain(descriptor);
      if (result.usesIndex) return;
      logger.logWarning(_buildMessage(descriptor, where, result));
    }
  }

  String _buildMessage(
    QueryDescriptor descriptor,
    PredicateTree where,
    ExplainResult result,
  ) {
    final cols = _collectFieldNames(where).join(', ');
    return 'missing-index: query on "${descriptor.table}" filters by '
        '($cols) without an index. Plan: ${result.raw}';
  }

  List<String> _collectFieldNames(PredicateTree tree) => switch (tree) {
    LeafNode(:final Predicate predicate) => <String>[predicate.fieldName],
    AndNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._collectFieldNames(left),
      ..._collectFieldNames(right),
    ],
    OrNode(:final PredicateTree left, :final PredicateTree right) => <String>[
      ..._collectFieldNames(left),
      ..._collectFieldNames(right),
    ],
    NotNode(:final PredicateTree child) => _collectFieldNames(child),
    GroupNode(:final PredicateTree child) => _collectFieldNames(child),
    ColumnNode(:final String leftField, :final String rightField) => <String>[
      leftField,
      rightField,
    ],
    ExistsNode() => const <String>[],
    RawNode() => const <String>[],
  };
}
