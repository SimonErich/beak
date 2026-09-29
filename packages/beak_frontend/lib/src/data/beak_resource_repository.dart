import 'package:beak_core/beak_core.dart';

import 'beak_run.dart';

/// The frontend's catch boundary: every data-source call is wrapped into a
/// typed [BeakResult], so view models switch on outcomes and never
/// `try/catch` themselves.
///
/// A thin wrapper over a [BeakDataSource]: each method mirrors a
/// source operation but returns `BeakResult<T>` instead of throwing, so a
/// thrown [BeakException] surfaces as [BeakErr] and any other error still
/// propagates.
///
/// ```dart
/// final repository = BeakResourceRepository(dataSource);
/// final result = await repository.query(
///   const BeakQuerySpec(table: 'products'),
/// );
/// switch (result) {
///   case BeakOk(:final value):
///     print('${value.items.length} products');
///   case BeakErr(:final error):
///     print('load failed: ${error.message}');
/// }
/// ```
final class BeakResourceRepository {
  /// Creates a repository over [dataSource].
  const BeakResourceRepository(this.dataSource) : _queries = null;

  /// Shares identical pending queries within one owner. Completed reads are
  /// never cached; call [invalidateQueries] when its data or actor changes.
  BeakResourceRepository.coalescing(this.dataSource) : _queries = {};

  final Map<BeakQuerySpec, Future<BeakResult<BeakPage<BeakRecord>>>>? _queries;

  /// Prevents a new read from joining a request started before invalidation.
  /// Existing callers retain their response and apply their own version guard.
  void invalidateQueries() => _queries?.clear();

  /// The source calls run against.
  final BeakDataSource dataSource;

  /// Runs an injected typed operation through the same error boundary.
  Future<BeakResult<T>> run<T>(Future<T> Function() operation) =>
      beakRun(operation);

  /// Runs a query, capturing failures as [BeakErr].
  // --8<-- [start:query]
  Future<BeakResult<BeakPage<BeakRecord>>> query(BeakQuerySpec spec) {
    final queries = _queries;
    if (queries == null) return beakRun(() => dataSource.query(spec));
    return queries.putIfAbsent(spec, () {
      late final Future<BeakResult<BeakPage<BeakRecord>>> request;
      request = (() async {
        try {
          return await beakRun(() => dataSource.query(spec));
        } finally {
          queries.removeWhere(
            (key, pending) => key == spec && identical(pending, request),
          );
        }
      })();
      return request;
    });
  }
  // --8<-- [end:query]

  /// Computes an aggregate, capturing failures as [BeakErr].
  Future<BeakResult<num>> aggregate(BeakAggregateSpec spec) =>
      beakRun(() => dataSource.aggregate(spec));

  // --8<-- [start:getOne]
  /// Fetches one record; a missing id is a [BeakErr] with a not-found.
  Future<BeakResult<BeakRecord>> getOne(String table, Object id) => beakRun(
    () async =>
        await dataSource.getOne(table, id) ??
        (throw BeakNotFoundException('No record of "$table" with id "$id".')),
  );
  // --8<-- [end:getOne]

  /// Fetches many records by id in one round trip, capturing failures as
  /// [BeakErr]. Missing ids are simply absent from the result.
  Future<BeakResult<List<BeakRecord>>> batchGet(
    String table,
    List<Object> ids,
  ) => beakRun(() => dataSource.batchGet(table, ids));

  /// Creates a record, capturing failures as [BeakErr].
  Future<BeakResult<BeakRecord>> create(String table, BeakRecord data) =>
      beakRun(() => dataSource.create(table, data));

  /// Updates a record, capturing failures as [BeakErr].
  Future<BeakResult<BeakRecord>> update(
    String table,
    Object id,
    BeakRecord data,
  ) => beakRun(() => dataSource.update(table, id, data));

  /// Deletes a record, capturing failures as [BeakErr].
  Future<BeakResult<void>> delete(
    String table,
    Object id, {
    bool force = false,
  }) => beakRun(() => dataSource.delete(table, id, force: force));

  /// Links related ids, capturing failures as [BeakErr].
  Future<BeakResult<void>> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => beakRun(() => dataSource.attach(table, id, relationKey, relatedIds));

  /// Unlinks related ids, capturing failures as [BeakErr].
  Future<BeakResult<void>> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => beakRun(() => dataSource.detach(table, id, relationKey, relatedIds));
}
