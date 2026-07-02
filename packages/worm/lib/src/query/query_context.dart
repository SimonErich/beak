/// Per-model context used by `QueryBuilder<T>`.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../relation/relation.dart';
import '../scope/global_scope.dart';

/// Hydrator: converts a raw row into a typed model.
typedef Hydrator<T> = T Function(Map<String, Object?> row);

/// Immutable per-model context.
///
/// Carries everything `QueryBuilder<T>` needs to
/// produce, execute, and hydrate queries for [T].
final class QueryContext<T extends Model> {
  /// Creates a [QueryContext].
  const QueryContext({
    required this.adapter,
    required this.table,
    required this.hydrate,
    this.primaryKey = 'id',
    this.globalScopes = const <GlobalScope<Model>>[],
    this.relations = const <String, Relation<Model, Model>>{},
  });

  /// Adapter executing the queries.
  final DatabaseAdapter adapter;

  /// Snake_case table name.
  final String table;

  /// Primary key column name.
  final String primaryKey;

  /// Hydrator turning a row into a model instance.
  final Hydrator<T> hydrate;

  /// Global scopes auto-applied to every query.
  final List<GlobalScope<Model>> globalScopes;

  /// Declared relations keyed by name.
  final Map<String, Relation<Model, Model>> relations;
}
