import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';

/// Defaults the response `content-type` to JSON when the handler set none,
/// leaving explicit content types (CSV exports, file downloads) untouched.
// --8<-- [start:beakJsonMiddleware]
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
// --8<-- [end:beakJsonMiddleware]

/// The largest JSON request body [readJsonObject] reads unless told otherwise:
/// 16 MiB, room for a graph commit that saves thousands of rows and small
/// enough that an anonymous caller cannot make the server buffer a gigabyte.
const int beakMaxJsonBodyInBytes = 16 * 1024 * 1024;

/// Reads and decodes [request]'s body as a JSON object.
///
/// Throws a [BeakValidationException] when the body is not UTF-8, not valid
/// JSON or not a JSON object, and a [BeakPayloadTooLargeException] when it is
/// longer than [maxBodyInBytes] (the declared length is checked first, and a
/// body that lies about it is cut off while it streams). The error-mapping
/// middleware turns those into a 422 and a 413. Use it as the first line of any
/// handler that expects a JSON payload:
///
/// ```dart
/// Future<Response> create(Request request) async {
///   final body = await readJsonObject(request);
///   final name = body['name']; // already a decoded Map<String, Object?>
///   // ...
/// }
/// ```
Future<Map<String, Object?>> readJsonObject(
  Request request, {
  int maxBodyInBytes = beakMaxJsonBodyInBytes,
}) async {
  final int? declaredLength = request.contentLength;
  if (declaredLength != null && declaredLength > maxBodyInBytes) {
    throw _bodyTooLarge(maxBodyInBytes);
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    bytes.add(chunk);
    if (bytes.length > maxBodyInBytes) {
      throw _bodyTooLarge(maxBodyInBytes);
    }
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
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

BeakPayloadTooLargeException _bodyTooLarge(int maxBodyInBytes) =>
    BeakPayloadTooLargeException(
      'The request body is larger than the $maxBodyInBytes bytes this server '
      'reads.',
    );

/// Decodes an already-read JSON [body] into a typed spec via [decode],
/// turning the decoder's [BeakConfigurationException] into a
/// [BeakValidationException] so a malformed client spec maps to a 422 — never
/// an opaque 500. Shared by every spec-accepting handler (query, aggregate,
/// export):
///
/// ```dart
/// final spec = readBeakSpec(
///   await readJsonObject(request),
///   BeakQuerySpec.fromJson,
/// );
/// ```
T readBeakSpec<T>(
  Map<String, Object?> body,
  T Function(Map<String, Object?> json) decode,
) {
  try {
    return decode(body);
  } on BeakConfigurationException catch (exception) {
    throw BeakValidationException('Malformed spec body: ${exception.message}');
  }
}
