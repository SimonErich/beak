import 'package:shelf/shelf.dart';

/// Adds CORS headers to every response and short-circuits `OPTIONS`
/// preflight requests with `204 No Content`.
Middleware beakCorsMiddleware({String allowedOrigin = '*'}) {
  final headers = <String, String>{
    'access-control-allow-origin': allowedOrigin,
    'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers': 'authorization, content-type, x-request-id',
  };
  return (Handler inner) => (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: headers);
    }
    final Response response = await inner(request);
    return response.change(headers: headers);
  };
}
