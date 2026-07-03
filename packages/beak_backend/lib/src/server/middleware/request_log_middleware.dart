import 'dart:math';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

const String _requestIdContextKey = 'beak.requestId';

/// One served request, as reported to a [BeakRequestLogger].
@immutable
final class BeakRequestLogEntry {
  /// Creates a log entry describing a served request.
  const BeakRequestLogEntry({
    required this.requestId,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.duration,
  });

  /// The id correlating this request across log lines and error bodies.
  final String requestId;

  /// The HTTP method served.
  final String method;

  /// The request path relative to the handler root.
  final String path;

  /// The status code of the response.
  final int statusCode;

  /// How long the downstream handler took.
  final Duration duration;

  @override
  String toString() =>
      '[$requestId] $method /$path -> $statusCode '
      '(${duration.inMilliseconds}ms)';
}

/// Receives one [BeakRequestLogEntry] per served request.
typedef BeakRequestLogger = void Function(BeakRequestLogEntry entry);

/// Produces request ids for requests that arrive without one.
typedef BeakRequestIdFactory = String Function();

/// The request id assigned by [beakRequestLogMiddleware], or `null` when the
/// middleware is not installed.
String? beakRequestId(Request request) =>
    switch (request.context[_requestIdContextKey]) {
      final String id => id,
      _ => null,
    };

/// Tags every request with an id (reusing an incoming `x-request-id`),
/// echoes it as a response header, and reports the served request to
/// [onRequest].
Middleware beakRequestLogMiddleware({
  required BeakRequestLogger onRequest,
  BeakRequestIdFactory? requestIdFactory,
}) {
  final BeakRequestIdFactory nextRequestId =
      requestIdFactory ?? _randomRequestId;
  return (Handler inner) => (Request request) async {
    final stopwatch = Stopwatch()..start();
    final String requestId = request.headers['x-request-id'] ?? nextRequestId();
    final Response response = await inner(
      request.change(context: {_requestIdContextKey: requestId}),
    );
    stopwatch.stop();
    onRequest(
      BeakRequestLogEntry(
        requestId: requestId,
        method: request.method,
        path: request.url.path,
        statusCode: response.statusCode,
        duration: stopwatch.elapsed,
      ),
    );
    return response.change(headers: {'x-request-id': requestId});
  };
}

final Random _random = Random();

String _randomRequestId() => [
  for (var i = 0; i < 16; i += 1) _random.nextInt(16).toRadixString(16),
].join();
