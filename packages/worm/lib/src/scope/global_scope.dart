/// Global query scopes.
library;

import '../model/model.dart';
import '../query/query_builder.dart';

/// A query modifier auto-applied to every
/// [QueryBuilder] created from a model.
///
/// Implementations supply a unique [name] used by
/// `QueryBuilder.withoutGlobalScope` to bypass the
/// scope and an [apply] method that returns a new,
/// constrained builder.
abstract class GlobalScope<T extends Model> {
  /// Creates a [GlobalScope].
  const GlobalScope();

  /// Unique identifier of this scope.
  String get name;

  /// Apply this scope to [builder] and return the
  /// resulting (constrained) builder.
  QueryBuilder<T> apply(QueryBuilder<T> builder);
}
