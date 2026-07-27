import 'package:beak_core/beak_core.dart';

/// A [BeakDataSource] decorator that records every call and forwards it.
///
/// Wrap a real source — usually [BeakDataSource] implementations that behave,
/// like `InMemoryBeakDataSource` — when a test needs to assert *how* a widget
/// talked to the backend rather than only what it rendered: that a list page
/// costs one `query` and not one per row, that a row action batches its reads,
/// that a filter reached the spec.
///
/// ```dart
/// final source = BeakRecordingDataSource(
///   InMemoryBeakDataSource(registry: registry)..seed(const ProductModel(), rows),
/// );
/// await tester.pumpWidget(panel(source));
/// expect(source.queryCalls, hasLength(1));
/// expect(source.queryCalls.single.relationLoads, hasLength(1));
/// ```
///
/// Recording only — every call reaches [inner] unchanged, so behaviour under
/// test is the real thing. Extend it to make one operation fail while the
/// rest keeps working.
base class BeakRecordingDataSource implements BeakDataSource {
  /// Records calls made to [inner].
  BeakRecordingDataSource(this.inner);

  /// The source every call is forwarded to.
  final BeakDataSource inner;

  /// Every `query` spec, in call order.
  final List<BeakQuerySpec> queryCalls = [];

  /// Every `getOne` call, as `(table, id)` pairs.
  final List<(String, Object)> getOneCalls = [];

  /// Every `batchGet` call, as `(table, ids)` pairs.
  final List<(String, List<Object>)> batchGetCalls = [];

  /// Every `create` call, as `(table, data)` pairs.
  final List<(String, BeakRecord)> createCalls = [];

  /// Every `update` call, as `(table, id, data)` triples.
  final List<(String, Object, BeakRecord)> updateCalls = [];

  /// Every `delete` call, as `(table, id, force)` triples.
  final List<(String, Object, bool)> deleteCalls = [];

  /// Every `restore` call, as `(table, id)` pairs.
  final List<(String, Object)> restoreCalls = [];

  /// Every `attach` call, as `(table, id, relationKey, relatedIds)` tuples.
  final List<(String, Object, String, List<Object>)> attachCalls = [];

  /// Every `detach` call, as `(table, id, relationKey, relatedIds)` tuples.
  final List<(String, Object, String, List<Object>)> detachCalls = [];

  /// Every `aggregate` spec, in call order.
  final List<BeakAggregateSpec> aggregateCalls = [];

  /// Forgets every recorded call, so a later assertion counts only what
  /// happened after this point.
  void clearRecordedCalls() {
    queryCalls.clear();
    getOneCalls.clear();
    batchGetCalls.clear();
    createCalls.clear();
    updateCalls.clear();
    deleteCalls.clear();
    restoreCalls.clear();
    attachCalls.clear();
    detachCalls.clear();
    aggregateCalls.clear();
  }

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
    queryCalls.add(spec);
    return inner.query(spec);
  }

  @override
  Future<BeakRecord?> getOne(String table, Object id) {
    getOneCalls.add((table, id));
    return inner.getOne(table, id);
  }

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) {
    batchGetCalls.add((table, ids));
    return inner.batchGet(table, ids);
  }

  @override
  Future<BeakRecord> create(String table, BeakRecord data) {
    createCalls.add((table, data));
    return inner.create(table, data);
  }

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) {
    updateCalls.add((table, id, data));
    return inner.update(table, id, data);
  }

  @override
  Future<void> delete(String table, Object id, {bool force = false}) {
    deleteCalls.add((table, id, force));
    return inner.delete(table, id, force: force);
  }

  @override
  Future<BeakRecord> restore(String table, Object id) {
    restoreCalls.add((table, id));
    return inner.restore(table, id);
  }

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) {
    attachCalls.add((table, id, relationKey, relatedIds));
    return inner.attach(table, id, relationKey, relatedIds);
  }

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) {
    detachCalls.add((table, id, relationKey, relatedIds));
    return inner.detach(table, id, relationKey, relatedIds);
  }

  @override
  Future<num> aggregate(BeakAggregateSpec spec) {
    aggregateCalls.add(spec);
    return inner.aggregate(spec);
  }
}
