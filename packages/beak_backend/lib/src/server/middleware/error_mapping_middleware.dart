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
///
/// A [BeakStorageException] and a [BeakInternalException] are the typed
/// failures that are also opaque. A storage message quotes the system behind
/// the driver, so the caller gets `File storage failed.`; an internal message
/// describes a broken invariant, so the caller gets `Internal server error.`.
/// Either way [onUnexpectedError] gets the exception with its detail.
// --8<-- [start:beakErrorMappingMiddleware]
Middleware beakErrorMappingMiddleware({
  BeakUnexpectedErrorListener? onUnexpectedError,
}) =>
    (Handler inner) => (Request request) async {
      try {
        return await inner(request);
      } on BeakException catch (exception, stackTrace) {
        if (exception is BeakStorageException) {
          // A driver's message quotes the failure of the system behind it
          // (an endpoint, a bucket, a host). The operator gets all of it; the
          // caller learns only that storage failed.
          onUnexpectedError?.call(exception, stackTrace);
          return _jsonResponse(500, {
            'code': exception.code,
            'message': 'File storage failed.',
            ..._requestIdEntry(request),
          });
        }
        if (exception is BeakInternalException) {
          onUnexpectedError?.call(exception, stackTrace);
          return _jsonResponse(500, {
            'code': exception.code,
            'message': 'Internal server error.',
            ..._requestIdEntry(request),
          });
        }
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
// --8<-- [end:beakErrorMappingMiddleware]

Response _exceptionResponse(BeakException exception, Request request) {
  // --8<-- [start:exceptionStatus]
  final int statusCode = switch (exception) {
    BeakValidationException() => 422,
    BeakNotFoundException() => 404,
    BeakAuthenticationException() => 401,
    BeakAuthorizationException() => 403,
    BeakConflictException() => 409,
    BeakConfigurationException() => 500,
    BeakStorageException() => 500,
    BeakInternalException() => 500,
    BeakPayloadTooLargeException() => 413,
    BeakTransportException() => 502,
  };
  // --8<-- [end:exceptionStatus]
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
