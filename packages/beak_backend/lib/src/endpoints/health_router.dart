import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// The two probes every container platform asks for.
///
/// Kubernetes, Cloud Run, Fly and ECS all want the same distinction, and
/// conflating them is how a rolling deploy takes a service down: the liveness
/// probe decides whether to *restart* the process, the readiness probe decides
/// whether to *route traffic* to it. A database blip must move traffic away,
/// never kill the process.
///
/// - `GET /healthz` — 200 as long as the process is serving. Never touches
///   the database, so a database outage cannot trigger a restart loop.
/// - `GET /readyz` — 200 when the data source answers, 503 when it does not.
///
/// Mounted automatically by [beakApiRouter], outside `/api` so they are not
/// subject to auth.
Router beakHealthRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
}) => Router()
  ..get('/healthz', (Request request) => _json(200, {'status': 'ok'}))
  ..get('/readyz', (Request request) => _readiness(registry, dataSource));

/// Whether the data source answers, as a readiness response.
Future<Response> _readiness(
  BeakModelRegistry registry,
  BeakDataSource dataSource,
) async {
  final BeakModel? probe = registry.all.isEmpty ? null : registry.all.first;
  if (probe == null) {
    // Nothing registered: the process is serving an empty API, which is a
    // configuration problem rather than an outage. Ready, and say why.
    return _json(200, {'status': 'ok', 'detail': 'no models registered'});
  }
  try {
    await dataSource.aggregate(BeakAggregateSpec.count(table: probe.table));
    return _json(200, {'status': 'ok'});
  } on Object catch (error) {
    // Any failure at all means "do not send me traffic". The message is the
    // exception's own, so an operator sees the real cause in the probe
    // response rather than having to correlate it with the logs.
    return _json(503, {'status': 'unavailable', 'detail': '$error'});
  }
}

Response _json(int statusCode, Map<String, Object?> body) => Response(
  statusCode,
  body: jsonEncode(body),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
