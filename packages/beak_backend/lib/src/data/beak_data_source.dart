import 'package:beak_core/beak_core.dart';

/// The source-agnostic data boundary of a Beak backend.
///
/// Handlers and services speak only this interface; `WormDataSource` is the
/// default implementation and a future `beak_serverpod` package can supply
/// another without touching `beak_core` or the handlers. Implementations
/// throw typed `BeakException`s (`BeakNotFoundException` for missing
/// records, `BeakConfigurationException` for unknown tables/relations) and
/// never leak ORM types.
abstract interface class BeakDataSource {
  /// Runs [spec] and returns the requested page of typed records, with
  /// every relation load in the spec eagerly resolved (Beak never
  /// lazy-loads).
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);

  /// The record of [table] with primary key [id], or `null` when it does
  /// not exist (or is soft-deleted).
  Future<BeakRecord?> getOne(String table, Object id);

  /// Inserts [data] into [table] and returns the stored record (including
  /// database-assigned values).
  Future<BeakRecord> create(String table, BeakRecord data);

  /// Updates the record of [table] with primary key [id] with the values of
  /// [data] and returns the stored result.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<BeakRecord> update(String table, Object id, BeakRecord data);

  /// Deletes the record of [table] with primary key [id] — softly when the
  /// model opts into soft deletes, unless [force] hard-deletes.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<void> delete(String table, Object id, {bool force = false});

  /// The records of [table] whose primary keys appear in [ids], fetched in
  /// a single query (the reference-deduplication path).
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids);

  /// Adds pivot rows linking the record of [table] with primary key [id] to
  /// [relatedIds] through the belongs-to-many relation [relationKey],
  /// skipping links that already exist.
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Removes the pivot rows linking the record of [table] with primary key
  /// [id] to [relatedIds] through the belongs-to-many relation
  /// [relationKey].
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Computes [spec]'s aggregate (count/sum/avg) over the matching rows,
  /// returning `0` when no rows match.
  Future<num> aggregate(BeakAggregateSpec spec);
}
