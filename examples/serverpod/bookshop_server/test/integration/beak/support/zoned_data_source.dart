import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart' show Session;

/// Runs every [BeakDataSource] call inside [BeakServerpod.runInSession]:
/// exactly how the engine runs Beak's pipeline, so the zone must survive
/// worm's query builder, eager loading and every await below it.
final class ZonedBeakDataSource implements BeakDataSource {
  /// Wraps [inner], entering [session]'s zone for each call.
  ZonedBeakDataSource(this.session, this.inner);

  /// The session the zone carries.
  final Session session;

  /// The source under test (a `WormDataSource` over the session adapter).
  final BeakDataSource inner;

  R _zoned<R>(R Function() body) => BeakServerpod.runInSession(session, body);

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      _zoned(() => inner.query(spec));

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      _zoned(() => inner.getOne(table, id));

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      _zoned(() => inner.create(table, data));

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      _zoned(() => inner.update(table, id, data));

  @override
  Future<void> delete(String table, Object id, {bool force = false}) =>
      _zoned(() => inner.delete(table, id, force: force));

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      _zoned(() => inner.restore(table, id));

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      _zoned(() => inner.batchGet(table, ids));

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _zoned(() => inner.attach(table, id, relationKey, relatedIds));

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _zoned(() => inner.detach(table, id, relationKey, relatedIds));

  @override
  Future<num> aggregate(BeakAggregateSpec spec) =>
      _zoned(() => inner.aggregate(spec));
}
