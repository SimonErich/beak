/// Eager-load specification carried by `QueryBuilder`.
library;

import 'predicate_tree.dart';

/// A single eager-load entry.
///
/// Each entry names a relation registered on the `QueryContext` and
/// may carry a nested relation path (dot-notation, e.g.
/// `'posts.comments'`) plus an optional per-head predicate that
/// constrains the child SELECT.
final class EagerLoad {
  /// Creates an [EagerLoad].
  const EagerLoad(this.path, {this.constrain, this.nested = const []});

  /// Dot-separated relation path
  /// (e.g. `'posts'` or `'posts.comments'`).
  final String path;

  /// Predicate AND-merged into the child SELECT for the [head]
  /// relation. The constraint applies only at the [head] segment;
  /// nested segments may pass their own constraint via a separate
  /// [EagerLoad] entry.
  final PredicateTree? constrain;

  /// Nested loads with independent predicates at each relationship level.
  final List<EagerLoad> nested;

  /// First segment of [path].
  String get head => path.split('.').first;

  /// Remaining segments after [head], or `null` when [path] has a
  /// single segment.
  String? get tail {
    final parts = path.split('.');
    if (parts.length <= 1) return null;
    return parts.sublist(1).join('.');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EagerLoad &&
          path == other.path &&
          constrain == other.constrain &&
          nested.length == other.nested.length &&
          List.generate(
            nested.length,
            (i) => nested[i] == other.nested[i],
          ).every((same) => same);

  @override
  int get hashCode => Object.hash(path, constrain, Object.hashAll(nested));
}

/// An aggregate to inject onto each loaded model.
///
/// Drives `withCount`, `withSum`, and `withExists`.
final class AggregateInjection {
  /// Creates an [AggregateInjection].
  const AggregateInjection({
    required this.relationName,
    required this.kind,
    required this.injectionKey,
    this.column,
    this.filter,
  });

  /// Relation name to aggregate over.
  final String relationName;

  /// Kind of aggregation.
  final AggregateKind kind;

  /// Key under which the aggregate value is stored in
  /// `Model.injectedFields`.
  final String injectionKey;

  /// Column used for `sum`. Ignored for `count` /
  /// `exists`.
  final String? column;

  /// Optional predicate AND-merged into the aggregate's child SELECT,
  /// so the count/sum/exists reflects only matching related rows.
  final PredicateTree? filter;
}

/// Kinds of aggregate injections.
enum AggregateKind {
  /// Number of related rows.
  count,

  /// Sum of a numeric child column.
  sum,

  /// Whether any related row exists.
  exists,
}
