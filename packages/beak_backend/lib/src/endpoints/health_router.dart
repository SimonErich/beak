import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../server/middleware/error_mapping_middleware.dart';

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
///   The 503 body names no cause: the probe is unauthenticated, and a driver's
///   message can carry a host name, a user or a query. The failure itself goes
///   to [onUnexpectedError], where the operator's logs already are.
///
/// Mounted automatically by [beakApiRouter], outside `/api` so they are not
/// subject to auth.
// --8<-- [start:beakHealthRouter]
Router beakHealthRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  BeakUnexpectedErrorListener? onUnexpectedError,
}) => Router()
  ..get('/healthz', (Request request) => _json(200, {'status': 'ok'}))
  ..get(
    '/readyz',
    (Request request) => _readiness(registry, dataSource, onUnexpectedError),
  );
// --8<-- [end:beakHealthRouter]

/// Whether the data source answers, as a readiness response.
Future<Response> _readiness(
  BeakModelRegistry registry,
  BeakDataSource dataSource,
  BeakUnexpectedErrorListener? onUnexpectedError,
) async {
  final BeakModel? probe = registry.all.isEmpty ? null : registry.all.first;
  if (probe == null) {
    // Nothing registered: the process is serving an empty API, which is a
    // configuration problem rather than an outage. Ready, and say why.
    return _json(200, {'status': 'ok', 'detail': 'no models registered'});
  }
  try {
    await dataSource.aggregate(probe.count());
    return _json(200, {'status': 'ok'});
  } on Object catch (error, stackTrace) {
    // Any failure at all means "do not send me traffic".
    onUnexpectedError?.call(error, stackTrace);
    return _json(503, {
      'status': 'unavailable',
      'detail': 'the data source did not answer',
    });
  }
}

Response _json(int statusCode, Map<String, Object?> body) => Response(
  statusCode,
  body: jsonEncode(body),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
