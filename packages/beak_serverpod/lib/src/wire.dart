import 'dart:convert';

import 'package:beak_core/beak_core.dart';

/// The only envelope version this build speaks.
const int beakWireVersion = 1;

/// What an HTTP method name looks like: letters, and hyphens after the
/// first. `shelf.Request` throws on an empty one, so the server refuses it
/// with a 400 before it gets that far.
final RegExp _methodName = RegExp(r'^[A-Za-z][A-Za-z-]{0,15}$');

/// Request headers the tunnel carries. Everything else stays behind, so
/// credentials (`authorization`, `cookie`) and proxy claims
/// (`x-forwarded-*`) can never reach Beak through the envelope: the server
/// takes identity from the Serverpod session alone.
// --8<-- [start:beakWireRequestHeaders]
const Set<String> beakWireRequestHeaders = {
  'content-type',
  'accept',
  'if-unmodified-since',
  'x-beak-request-id',
};
// --8<-- [end:beakWireRequestHeaders]

/// One Beak HTTP request, flattened into the string a single Serverpod
/// endpoint method can carry (envelope v1).
///
/// ```dart
/// final wire = BeakWireRequest(method: 'POST', path: '/api/book/query',
///     body: jsonEncode(spec.toJson()));
/// final reply = BeakWireResponse.decode(await dispatch(wire.encode()));
/// ```
final class BeakWireRequest {
  /// Describes a request; [headers] are filtered to [beakWireRequestHeaders]
  /// and lower-cased.
  BeakWireRequest({
    required this.method,
    required this.path,
    this.query = '',
    Map<String, String> headers = const {},
    this.body = '',
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           if (beakWireRequestHeaders.contains(key.toLowerCase()))
             key.toLowerCase(): value,
       });

  /// Strictly decodes an envelope; anything else is a
  /// [BeakValidationException].
  factory BeakWireRequest.decode(String envelope) {
    final Object? decoded;
    try {
      decoded = jsonDecode(envelope);
    } on FormatException {
      throw const BeakValidationException('Malformed Beak tunnel request.');
    }
    return switch (decoded) {
      {
        'v': beakWireVersion,
        'method': final String method,
        'path': final String path,
        'query': final String query,
        'headers': final Map<String, Object?> headers,
        'body': final String body,
      }
          when _methodName.hasMatch(method) =>
        BeakWireRequest(
          method: method,
          path: path,
          query: query,
          headers: {
            for (final MapEntry(:key, :value) in headers.entries)
              if (value case final String text) key: text,
          },
          body: body,
        ),
      {'v': final Object? version} when version != beakWireVersion =>
        throw BeakValidationException(
          'Unsupported Beak tunnel version $version (this server speaks '
          '$beakWireVersion).',
        ),
      _ => throw const BeakValidationException(
        'Malformed Beak tunnel request.',
      ),
    };
  }

  /// HTTP method, upper case.
  final String method;

  /// Percent-encoded path, starting with `/`.
  final String path;

  /// Percent-encoded query string without the `?`.
  final String query;

  /// Allowlisted, lower-cased request headers.
  final Map<String, String> headers;

  /// Request body as text.
  final String body;

  /// The envelope string.
  String encode() => jsonEncode({
    'v': beakWireVersion,
    'method': method,
    'path': path,
    'query': query,
    'headers': headers,
    'body': body,
  });
}

/// One Beak HTTP response, as the tunnel returns it (envelope v1).
final class BeakWireResponse {
  /// Describes a response.
  const BeakWireResponse({
    required this.status,
    this.headers = const {},
    this.body = '',
  });

  /// Strictly decodes an envelope; anything else is a [FormatException].
  factory BeakWireResponse.decode(String envelope) =>
      switch (jsonDecode(envelope)) {
        {
          'status': final int status,
          'headers': final Map<String, Object?> headers,
          'body': final String body,
        } =>
          BeakWireResponse(
            status: status,
            headers: {
              for (final MapEntry(:key, :value) in headers.entries)
                if (value case final String text) key: text,
            },
            body: body,
          ),
        _ => throw const FormatException('Malformed Beak tunnel response.'),
      };

  /// HTTP status code.
  final int status;

  /// Response headers.
  final Map<String, String> headers;

  /// Response body as text.
  final String body;

  /// The envelope string.
  String encode() =>
      jsonEncode({'status': status, 'headers': headers, 'body': body});
}
