import 'package:beak_core/beak_core.dart';

import 'resource.dart';

/// Maps known transport/domain exceptions; null preserves an unexpected failure.
typedef ServerpodExceptionMapper =
    BeakException? Function(Exception exception, StackTrace stackTrace);

/// Dispatches Beak operations to typed, authenticated Serverpod client bindings.
final class ServerpodDataSource implements BeakDataSource, BeakEditDataSource {
  /// Registers [resources], rejecting ambiguous logical resource keys.
  ServerpodDataSource({
    required List<ServerpodResourceBinding> resources,
    this.mapException,
  }) {
    for (final resource in resources) {
      final key = resource.model.table;
      if (key.isEmpty || _resources.containsKey(key)) {
        throw BeakConfigurationException(
          'Invalid or duplicate resource "$key".',
        );
      }
      _resources[key] = resource;
    }
  }

  /// Optional mapping of known RPC failures into safe Beak outcomes.
  final ServerpodExceptionMapper? mapException;

  final Map<String, ServerpodResourceBinding> _resources = {};

  /// The binding for [resource]; never forwards an arbitrary table to the server.
  ServerpodResourceBinding binding(String resource) =>
      _resources[resource] ??
      (throw BeakConfigurationException('Unknown resource "$resource".'));

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on BeakException {
      rethrow;
    } on Exception catch (error, stack) {
      final mapped = mapException?.call(error, stack);
      if (mapped != null) Error.throwWithStackTrace(mapped, stack);
      rethrow;
    }
  }

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      _guard(() => binding(spec.table).queryRecords(spec));

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      _guard(() => binding(table).getOne(id));

  /// Loads the distinct edit command shape through the same error boundary.
  @override
  Future<BeakRecord> loadEditValues(String table, Object id) =>
      _guard(() => binding(table).loadEditValues(id));

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      _guard(() => binding(table).create(data));

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      _guard(() => binding(table).update(id, data));

  @override
  Future<void> delete(String table, Object id, {bool force = false}) =>
      _guard(() => binding(table).delete(id, force: force));

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      _guard(() => binding(table).restore(id));

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) =>
      _guard(() => binding(table).batchGet(ids));

  @override
  Future<num> aggregate(BeakAggregateSpec spec) =>
      _guard(() => binding(spec.table).aggregate(spec));

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _guard(() async {
    binding(table);
    unsupportedServerpodOperation(table, 'attach');
  });

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) => _guard(() async {
    binding(table);
    unsupportedServerpodOperation(table, 'detach');
  });
}
