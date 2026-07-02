/// Reusable local query scopes.
library;

import '../model/model.dart';
import '../query/query_builder.dart';

/// A reusable predicate fragment applied on demand.
///
/// Local scopes are opt-in (never auto-applied) and
/// compose freely with global scopes. Apply via
/// `QueryBuilder.scope(...)` or chain a scope inside
/// a domain-specific extension method.
abstract class LocalScope<T extends Model> {
  /// Creates a [LocalScope].
  const LocalScope();

  /// Apply this scope to [builder].
  QueryBuilder<T> apply(QueryBuilder<T> builder);
}

/// A [LocalScope] driven by a closure.
///
/// Useful for ad-hoc scopes that don't merit a
/// dedicated subclass.
final class CallableLocalScope<T extends Model> extends LocalScope<T> {
  /// Creates a [CallableLocalScope].
  const CallableLocalScope(this._apply);

  final QueryBuilder<T> Function(QueryBuilder<T>) _apply;

  @override
  QueryBuilder<T> apply(QueryBuilder<T> builder) => _apply(builder);
}
