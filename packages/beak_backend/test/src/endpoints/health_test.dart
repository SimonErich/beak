import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A source whose every call fails, standing in for a database outage.
final class _DownDataSource implements BeakDataSource {
  const _DownDataSource();

  Never _down() => throw const BeakConfigurationException('connection refused');

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async => _down();

  @override
  Future<BeakRecord?> getOne(String table, Object id) async => _down();

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async => _down();

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) async =>
      _down();

  @override
  Future<void> delete(String table, Object id, {bool force = false}) async =>
      _down();

  @override
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids) async =>
      _down();

  @override
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async => _down();

  @override
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  ) async => _down();

  @override
  Future<BeakRecord> restore(String table, Object id) async => _down();

  @override
  Future<num> aggregate(BeakAggregateSpec spec) async => _down();
}

Handler handlerFor(BeakModelRegistry registry, BeakDataSource dataSource) =>
    const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(beakApiRouter(registry: registry, dataSource: dataSource));

Future<Response> get(Handler handler, String path) async =>
    await handler(Request('GET', Uri.parse('http://localhost$path')));

Future<Map<String, Object?>> bodyOf(Response response) async =>
    switch (jsonDecode(await response.readAsString())) {
      final Map<String, Object?> map => map,
      final Object? other => throw StateError('expected an object, got $other'),
    };

void main() {
  late BeakModelRegistry registry;
  late InMemoryAdapter adapter;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    registry = createApiRegistry();
  });

  tearDown(Worm.reset);

  group('GET /healthz', () {
    test('reports ok without touching the database', () async {
      // Liveness decides whether to restart the process. A database outage
      // must never do that, so this probe must not read one.
      final response = await get(
        handlerFor(registry, const _DownDataSource()),
        '/healthz',
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), {'status': 'ok'});
    });
  });

  group('GET /readyz', () {
    test('reports ok when the data source answers', () async {
      final response = await get(
        handlerFor(registry, WormDataSource(registry, adapter: adapter)),
        '/readyz',
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), {'status': 'ok'});
    });

    test('reports 503 and the cause when it does not', () async {
      // Readiness decides whether to route traffic. This is the one that must
      // fail, so a rolling deploy drains rather than serving errors.
      final response = await get(
        handlerFor(registry, const _DownDataSource()),
        '/readyz',
      );

      expect(response.statusCode, 503);
      final body = await bodyOf(response);
      expect(body['status'], 'unavailable');
      expect(body['detail'], contains('connection refused'));
    });

    test('an empty registry is ready, and says why', () async {
      final response = await get(
        handlerFor(BeakModelRegistry(), const _DownDataSource()),
        '/readyz',
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), {
        'status': 'ok',
        'detail': 'no models registered',
      });
    });
  });

  test('the probes sit outside /api, so auth does not guard them', () async {
    // A platform's probe arrives with no credentials by design.
    final handler = handlerFor(
      registry,
      WormDataSource(registry, adapter: adapter),
    );

    expect((await get(handler, '/healthz')).statusCode, 200);
    expect((await get(handler, '/api/healthz')).statusCode, 404);
  });
}
