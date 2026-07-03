import 'package:beak_core/beak_core.dart';

/// The frontend's catch boundary: every data-source call is wrapped into a
/// typed [BeakResult], so view models switch on outcomes and never
/// `try/catch` themselves.
final class BeakResourceRepository {
  /// Creates a repository over [dataSource].
  const BeakResourceRepository(this.dataSource);

  /// The source calls run against.
  final BeakDataSource dataSource;

  /// Runs a query, capturing failures as [BeakErr].
  Future<BeakResult<BeakPage<BeakRecord>>> query(BeakQuerySpec spec) =>
      _guard(() => dataSource.query(spec));

  /// Computes an aggregate, capturing failures as [BeakErr].
  Future<BeakResult<num>> aggregate(BeakAggregateSpec spec) =>
      _guard(() => dataSource.aggregate(spec));

  /// Fetches one record; a missing id is a [BeakErr] with a not-found.
  Future<BeakResult<BeakRecord>> getOne(String table, Object id) => _guard(
    () async =>
        await dataSource.getOne(table, id) ??
        (throw BeakNotFoundException('No record of "$table" with id "$id".')),
  );

  /// Creates a record, capturing failures as [BeakErr].
  Future<BeakResult<BeakRecord>> create(String table, BeakRecord data) =>
      _guard(() => dataSource.create(table, data));

  /// Updates a record, capturing failures as [BeakErr].
  Future<BeakResult<BeakRecord>> update(
    String table,
    Object id,
    BeakRecord data,
  ) => _guard(() => dataSource.update(table, id, data));

  /// Deletes a record, capturing failures as [BeakErr].
  Future<BeakResult<void>> delete(
    String table,
    Object id, {
    bool force = false,
  }) => _guard(() => dataSource.delete(table, id, force: force));

  /// Links related ids, capturing failures as [BeakErr].
  Future<BeakResult<void>> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _guard(() => dataSource.attach(table, id, relationKey, relatedIds));

  /// Unlinks related ids, capturing failures as [BeakErr].
  Future<BeakResult<void>> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _guard(() => dataSource.detach(table, id, relationKey, relatedIds));

  Future<BeakResult<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return BeakOk(await run());
    } on BeakException catch (exception) {
      return BeakErr(exception);
    }
  }
}
