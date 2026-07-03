import 'package:beak_core/beak_core.dart';

/// The frontend's [BeakDataSource] (and [BeakUploadClient]): every
/// operation delegates to the typed HTTP client — widgets and view models
/// stay transport-blind, and the interface stays identical to the
/// backend's worm-backed implementation.
final class HttpBeakDataSource implements BeakDataSource, BeakUploadClient {
  /// Creates a data source over [client].
  const HttpBeakDataSource(this.client);

  /// The transport the source delegates to.
  final BeakClient client;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      client.query(spec.table, spec);

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      client.getOne(table, id);

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      client.create(table, data);

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      client.update(table, id, data);

  @override
  Future<void> delete(String table, Object id, {bool force = false}) =>
      client.delete(table, id, force: force);

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      client.batchGet(table, ids);

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => client.attach(table, id, relationKey, relatedIds);

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => client.detach(table, id, relationKey, relatedIds);

  @override
  Future<BeakStoredFile> upload(
    String table,
    String columnKey,
    BeakUpload file,
  ) => client.upload(table, columnKey, file);

  @override
  Future<num> aggregate(BeakAggregateSpec spec) =>
      client.aggregate(spec.table, spec);
}
