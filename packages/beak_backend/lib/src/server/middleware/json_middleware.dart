import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';

/// Defaults the response `content-type` to JSON when the handler set none,
/// leaving explicit content types (CSV exports, file downloads) untouched.
Middleware beakJsonMiddleware() =>
    (Handler inner) => (Request request) async {
      final Response response = await inner(request);
      if (response.headers.containsKey('content-type')) {
        return response;
      }
      return response.change(
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };

/// Reads and decodes [request]'s body as a JSON object.
///
/// Throws a [BeakValidationException] when the body is not valid JSON or not
/// a JSON object — the error-mapping middleware turns that into a 422. Use it
/// as the first line of any handler that expects a JSON payload:
///
/// ```dart
/// Future<Response> create(Request request) async {
///   final body = await readJsonObject(request);
///   final name = body['name']; // already a decoded Map<String, Object?>
///   // ...
/// }
/// ```
Future<Map<String, Object?>> readJsonObject(Request request) async {
  final String body = await request.readAsString();
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error) {
    throw BeakValidationException(
      'Request body is not valid JSON: ${error.message}.',
    );
  }
  return switch (decoded) {
    final Map<String, Object?> map => map,
    final Object? other => throw BeakValidationException(
      'Request body must be a JSON object, got $other.',
    ),
  };
}
