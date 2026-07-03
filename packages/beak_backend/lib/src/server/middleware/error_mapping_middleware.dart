import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';

import 'request_log_middleware.dart';

/// Receives errors the error-mapping middleware could not type — the only
/// place unexpected failures surface, since their responses are opaque.
typedef BeakUnexpectedErrorListener =
    void Function(Object error, StackTrace stackTrace);

/// The catch boundary of the HTTP layer: maps every [BeakException] to its
/// status code and JSON body, and everything else to an opaque 500 (reported
/// to [onUnexpectedError]) so internals never leak to clients.
Middleware beakErrorMappingMiddleware({
  BeakUnexpectedErrorListener? onUnexpectedError,
}) =>
    (Handler inner) => (Request request) async {
      try {
        return await inner(request);
      } on BeakException catch (exception) {
        return _exceptionResponse(exception, request);
      } catch (error, stackTrace) {
        onUnexpectedError?.call(error, stackTrace);
        return _jsonResponse(500, {
          'code': 'internal',
          'message': 'Internal server error.',
          ..._requestIdEntry(request),
        });
      }
    };

Response _exceptionResponse(BeakException exception, Request request) {
  final int statusCode = switch (exception) {
    BeakValidationException() => 422,
    BeakNotFoundException() => 404,
    BeakAuthorizationException() => 403,
    BeakConflictException() => 409,
    BeakConfigurationException() => 500,
    BeakStorageException() => 500,
  };
  final Map<String, List<String>> fieldErrors = switch (exception) {
    BeakValidationException(:final fieldErrors) => fieldErrors,
    _ => const {},
  };
  return _jsonResponse(statusCode, {
    'code': exception.code,
    'message': exception.message,
    if (fieldErrors.isNotEmpty) 'fieldErrors': fieldErrors,
    ..._requestIdEntry(request),
  });
}

Map<String, String> _requestIdEntry(Request request) => {
  'requestId': ?beakRequestId(request),
};

Response _jsonResponse(int statusCode, Map<String, Object?> body) => Response(
  statusCode,
  body: jsonEncode(body),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
