import '../query/beak_aggregate_spec.dart';
import '../query/beak_page.dart';
import '../query/beak_query_spec.dart';
import '../query/beak_record.dart';

/// The source-agnostic data boundary both sides of Beak speak.
///
/// Backend handlers and services speak only this interface (`WormDataSource`
/// is the default implementation, `beak_frontend`'s HTTP client another,
/// and `beak_serverpod` supplies typed RPC bindings without database access).
/// Implementations
/// throw typed `BeakException`s (`BeakNotFoundException` for missing
/// records, `BeakConfigurationException` for unknown tables/relations) and
/// never leak ORM types.
///
/// ```dart
/// // Query a page with a filter, eager-loading a relation.
/// final page = await source.query(
///   const BeakQuerySpec(
///     table: 'products',
///     relationLoads: [BeakRelationLoad('category')],
///   ),
/// );
/// for (final record in page.items) {
///   print(record['name']?.raw);
/// }
///
/// // Create, then attach tags through a to-many relation.
/// final created = await source.create('products', newProduct);
/// await source.attach('products', created['id']!.raw!, 'tags', [tagId]);
/// ```
// --8<-- [start:BeakDataSource]
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

  /// Clears the soft-delete marker on the record with primary key [id],
  /// returning it as it now reads.
  ///
  /// A deletion the user can walk back is the difference between a panel
  /// people trust and one they are afraid of, and it only works if the row
  /// is still there — so this is the one operation that deliberately reaches
  /// past the soft-delete scope.
  ///
  /// Throws a [BeakNotFoundException] when no soft-deleted record has that
  /// id, and a [BeakValidationException] when the model does not soft-delete
  /// at all — restoring a hard-deleted row is not a thing that can be done,
  /// and reporting success would be a lie.
  Future<BeakRecord> restore(String table, Object id);

  /// The records of [table] whose primary keys appear in [ids], fetched in
  /// a single query (the reference-deduplication path).
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids);

  /// Links [relatedIds] to the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many inserts
  /// pivot rows (skipping links that already exist), has-many re-parents
  /// the related rows' foreign keys.
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Unlinks [relatedIds] from the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many removes
  /// the pivot rows, has-many clears the related rows' foreign keys.
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

// --8<-- [end:BeakDataSource]
