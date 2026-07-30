import 'package:beak_core/beak_core.dart';

import 'reference_cache.dart';

/// The frontend's catch boundary: every data-source call is wrapped into a
/// typed [BeakResult], so view models switch on outcomes and never
/// `try/catch` themselves.
///
/// A thin, stateless wrapper over a [BeakDataSource]: each method mirrors a
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
  /// Creates a repository over [dataSource], optionally resolving references
  /// through [referenceCache].
  const BeakResourceRepository(this.dataSource, {this.referenceCache});

  /// The source calls run against.
  final BeakDataSource dataSource;

  /// Coalesces and caches [resolveReference] lookups; when null each one is
  /// its own `getOne`.
  final ReferenceCache? referenceCache;

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

  /// Fetches one record *by reference* — a foreign key being turned into
  /// something a person can read.
  ///
  /// Unlike [getOne] this may be served from [referenceCache], so every
  /// picker on a form resolving its prefilled key in the same frame costs one
  /// `batchGet` between them. Use it where a stale label is harmless and a
  /// round trip per widget is not; use [getOne] to load a record for editing.
  Future<BeakResult<BeakRecord>> resolveReference(String table, Object id) =>
      switch (referenceCache) {
        null => getOne(table, id),
        final ReferenceCache cache => _guard(() => cache.resolve(table, id)),
      };

  /// Fetches many records by id in one round trip, capturing failures as
  /// [BeakErr]. Missing ids are simply absent from the result.
  Future<BeakResult<List<BeakRecord>>> batchGet(
    String table,
    List<Object> ids,
  ) => _guard(() => dataSource.batchGet(table, ids));

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
