import 'package:beak_core/beak_core.dart';

/// The frontend's [BeakDataSource] (and [BeakUploadClient]): every
/// operation delegates to the typed HTTP client — widgets and view models
/// stay transport-blind, and the interface stays identical to the
/// backend's worm-backed implementation.
///
/// This is the production source [registerBeakDependencies] wires up over a
/// [BeakClient] pointed at `apiBaseUrl`; tests inject a fake
/// [BeakDataSource] instead. Because it is source-agnostic, a future
/// transport (e.g. Serverpod) can replace it without touching the rest of
/// the frontend.
///
/// ```dart
/// final source = HttpBeakDataSource(
///   BeakClient(baseUrl: 'http://localhost:8080'),
/// );
/// final page = await source.query(const BeakQuerySpec(table: 'products'));
/// ```
final class HttpBeakDataSource
    implements
        BeakDataSource,
        BeakCapabilityDataSource,
        BeakSummaryDataSource,
        BeakExportDataSource,
        BeakValidationDataSource,
        BeakManagedUploadClient,
        BeakUploadUrlClient,
        BeakCommitDataSource {
  /// Creates a data source over [client].
  const HttpBeakDataSource(this.client);

  /// The transport the source delegates to.
  final BeakClient client;

  @override
  Future<BeakAccessCapabilities> capabilities(String table, {Object? id}) =>
      client.capabilities(table, id: id);

  @override
  Future<BeakValidationReport> validateRecord(BeakValidationRequest request) =>
      client.validateRecord(request);

  @override
  BeakCommitCapabilities get commitCapabilities =>
      const BeakCommitCapabilities(durableReceipts: true);

  @override
  Future<BeakSaveResult> commit(BeakSavePlan plan) => client.commit(plan);

  @override
  Future<BeakSaveResult> recover(String saveId) => client.recoverCommit(saveId);

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
  Future<BeakRecord> restore(String table, Object id) =>
      client.restore(table, id);

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
  Future<void> discardUpload(
    String table,
    String columnKey,
    BeakStoredFile file,
  ) => client.discardUpload(table, columnKey, file);

  @override
  Future<Uri> uploadUrl(String table, String columnKey, String key) =>
      client.uploadUrl(table, columnKey, key);

  @override
  Future<BeakSummaryResult> summary(BeakSummarySpec spec) =>
      client.summary(spec);

  @override
  Future<String> export(
    BeakQuerySpec spec, {
    List<BeakColumn>? columns,
    Map<String, BeakExportFormat> formats = const {},
    BeakFormatPolicy? formatting,
    bool raw = false,
  }) => client.export(
    spec.table,
    spec,
    columns: columns?.map((column) => column.key).toList(),
    formats: formats,
    formatting: formatting,
    raw: raw,
  );

  @override
  Future<num> aggregate(BeakAggregateSpec spec) =>
      client.aggregate(spec.table, spec);
}
