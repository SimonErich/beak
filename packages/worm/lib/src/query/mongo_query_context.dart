/// Adapter-context surface exposed via
/// `QueryBuilder.mongo(...)`.
library;

import '../model/model.dart';
import 'query_builder.dart';

/// Mongo-flavoured chainable surface returned by
/// `QueryBuilder.mongo(...)`.
///
/// Adds raw-filter and pipeline escape hatches that
/// only make sense against a document backend.
/// Construction is gated by `QueryBuilder.mongo`
/// which throws `AdapterMismatchException` for
/// non-Mongo adapters, so callers can rely on a
/// Mongo-capable adapter.
final class MongoQueryContext<T extends Model> {
  /// Creates a [MongoQueryContext] wrapping [_builder].
  const MongoQueryContext(
    this._builder, {
    Map<String, Object?> rawFilter = const <String, Object?>{},
    List<Map<String, Object?>> pipeline = const <Map<String, Object?>>[],
  }) : _rawFilter = rawFilter,
       _pipeline = pipeline;

  final QueryBuilder<T> _builder;
  final Map<String, Object?> _rawFilter;
  final List<Map<String, Object?>> _pipeline;

  /// The underlying builder.
  QueryBuilder<T> get builder => _builder;

  /// Extra `find()` filter expression injected by the
  /// caller.
  Map<String, Object?> get rawFilter => _rawFilter;

  /// Extra aggregation pipeline stages.
  List<Map<String, Object?>> get pipeline => _pipeline;

  /// Merge a raw filter expression.
  MongoQueryContext<T> withRawFilter(Map<String, Object?> filter) =>
      MongoQueryContext<T>(
        _builder,
        rawFilter: <String, Object?>{..._rawFilter, ...filter},
        pipeline: _pipeline,
      );

  /// Append aggregation [stages] to the pipeline.
  MongoQueryContext<T> withPipeline(List<Map<String, Object?>> stages) =>
      MongoQueryContext<T>(
        _builder,
        rawFilter: _rawFilter,
        pipeline: <Map<String, Object?>>[..._pipeline, ...stages],
      );
}
