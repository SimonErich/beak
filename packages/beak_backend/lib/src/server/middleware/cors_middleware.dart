import 'package:shelf/shelf.dart';

/// Adds CORS headers to every response and short-circuits `OPTIONS`
/// preflight requests with `204 No Content`.
///
/// [allowedOrigin] is the one origin a browser may call from; the default
/// `*` admits any, which suits a panel served from another port in
/// development. The allowed methods are the ones the generated routes use
/// (`GET`, `POST`, `PATCH`, `DELETE`); nothing in Beak answers `PUT`. The
/// allowed headers are the ones the Beak client sends:
/// `authorization`, `content-type`, `x-request-id`, and the
/// `if-unmodified-since` an edit carries for its optimistic lock.
// --8<-- [start:beakCorsMiddleware]
Middleware beakCorsMiddleware({String allowedOrigin = '*'}) {
  final headers = <String, String>{
    'access-control-allow-origin': allowedOrigin,
    'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers':
        'authorization, content-type, if-unmodified-since, x-request-id',
  };
  return (Handler inner) => (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: headers);
    }
    final Response response = await inner(request);
    return response.change(headers: headers);
  };
}

// --8<-- [end:beakCorsMiddleware]
