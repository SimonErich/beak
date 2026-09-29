import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Signs requests with AWS Signature Version 4, either as an `Authorization`
/// header or as a presigned URL.
///
/// It is the whole of what `HttpS3ObjectClient` needs to talk to AWS S3, MinIO
/// or any other S3-compatible store, and it is checked against the published
/// AWS test vectors. S3 rules apply to the canonical URI: it is encoded once,
/// never normalized.
///
/// ```dart
/// const signer = SigV4Signer(
///   accessKey: 'AKIAIOSFODNN7EXAMPLE',
///   secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
///   region: 'us-east-1',
/// );
/// final headers = signer.signHeaders(
///   method: 'GET',
///   url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
///   headers: {'host': 'examplebucket.s3.amazonaws.com'},
///   payloadSha256:
///       'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
///   timestamp: DateTime.now(),
/// );
/// ```
final class SigV4Signer {
  /// Creates a signer for [accessKey] and [secretKey] in [region], for
  /// [service] (S3 by default).
  const SigV4Signer({
    required this.accessKey,
    required this.secretKey,
    required this.region,
    this.service = 's3',
  });

  /// The access key id, sent in the credential scope.
  final String accessKey;

  /// The secret key the signing key is derived from. It is never sent.
  final String secretKey;

  /// The region the requests are scoped to, such as `us-east-1`.
  final String region;

  /// The service the requests are scoped to.
  final String service;

  /// The longest lifetime S3 accepts for a presigned URL, in seconds (7 days).
  static const int maxPresignLifetimeInSeconds = 604800;

  static const String _algorithm = 'AWS4-HMAC-SHA256';
  static const String _unsignedPayload = 'UNSIGNED-PAYLOAD';

  /// Signs a request and returns the headers to send: [headers] as given,
  /// plus `x-amz-date` and `authorization`.
  ///
  /// Every header in [headers] is signed, so it must include `host` and, for
  /// S3, `x-amz-content-sha256`. [payloadSha256] is the lowercase hex SHA-256
  /// of the body. [timestamp] is read in UTC.
  Map<String, String> signHeaders({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    required String payloadSha256,
    required DateTime timestamp,
  }) {
    final String amzDate = _amzDate(timestamp);
    final Map<String, String> canonicalHeaders = {
      for (final MapEntry<String, String> entry in headers.entries)
        entry.key.toLowerCase(): _collapseWhitespace(entry.value),
      'x-amz-date': amzDate,
    };
    final List<String> names = canonicalHeaders.keys.toList()..sort();
    final String signedHeaders = names.join(';');
    final String canonicalRequest = [
      method,
      _canonicalPath(url),
      _canonicalQuery(url.queryParametersAll),
      names.map((String name) => '$name:${canonicalHeaders[name]}\n').join(),
      signedHeaders,
      payloadSha256,
    ].join('\n');
    final String signature = _signature(canonicalRequest, amzDate);
    return {
      ...headers,
      'x-amz-date': amzDate,
      'authorization':
          '$_algorithm '
          'Credential=$accessKey/${_scope(amzDate)},'
          'SignedHeaders=$signedHeaders,'
          'Signature=$signature',
    };
  }

  /// A presigned URL: [url] with the signature in its query string, so a
  /// client without credentials can make the request until it expires.
  ///
  /// Only the `host` header is signed, and the payload is unsigned, which is
  /// what a browser following a plain link can satisfy. Throws an
  /// [ArgumentError] when [expiresInSeconds] is outside 1 to
  /// [maxPresignLifetimeInSeconds].
  Uri presignUrl({
    required String method,
    required Uri url,
    required int expiresInSeconds,
    required DateTime timestamp,
  }) {
    if (expiresInSeconds < 1 ||
        expiresInSeconds > maxPresignLifetimeInSeconds) {
      throw ArgumentError.value(
        expiresInSeconds,
        'expiresInSeconds',
        'must be between 1 and $maxPresignLifetimeInSeconds seconds',
      );
    }
    final String amzDate = _amzDate(timestamp);
    final Map<String, List<String>> query = {
      ...url.queryParametersAll,
      'X-Amz-Algorithm': [_algorithm],
      'X-Amz-Credential': ['$accessKey/${_scope(amzDate)}'],
      'X-Amz-Date': [amzDate],
      'X-Amz-Expires': ['$expiresInSeconds'],
      'X-Amz-SignedHeaders': ['host'],
    };
    final String canonicalQuery = _canonicalQuery(query);
    final String canonicalRequest = [
      method,
      _canonicalPath(url),
      canonicalQuery,
      'host:${hostHeaderOf(url)}\n',
      'host',
      _unsignedPayload,
    ].join('\n');
    final String signature = _signature(canonicalRequest, amzDate);
    return url.replace(query: '$canonicalQuery&X-Amz-Signature=$signature');
  }

  /// The `host` header value an HTTP client sends for [url]: the port is
  /// part of it unless it is the default for the scheme.
  static String hostHeaderOf(Uri url) {
    final int defaultPort = url.scheme == 'https' ? 443 : 80;
    return url.port == defaultPort ? url.host : '${url.host}:${url.port}';
  }

  String _scope(String amzDate) =>
      '${amzDate.substring(0, 8)}/$region/$service/aws4_request';

  String _signature(String canonicalRequest, String amzDate) {
    final String stringToSign = [
      _algorithm,
      amzDate,
      _scope(amzDate),
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    List<int> key = utf8.encode('AWS4$secretKey');
    for (final String part in [
      amzDate.substring(0, 8),
      region,
      service,
      'aws4_request',
    ]) {
      key = Hmac(sha256, key).convert(utf8.encode(part)).bytes;
    }
    return Hmac(sha256, key).convert(utf8.encode(stringToSign)).toString();
  }

  static String _amzDate(DateTime timestamp) {
    final DateTime utc = timestamp.toUtc();
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    return '${pad(utc.year, 4)}${pad(utc.month, 2)}${pad(utc.day, 2)}'
        'T${pad(utc.hour, 2)}${pad(utc.minute, 2)}${pad(utc.second, 2)}Z';
  }

  static String _collapseWhitespace(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// The path with each segment decoded and encoded again the S3 way, so a
  /// URL written with or without percent-escapes signs the same.
  static String _canonicalPath(Uri url) {
    if (url.path.isEmpty) {
      return '/';
    }
    return url.path
        .split('/')
        .map((String segment) => encodeComponent(Uri.decodeComponent(segment)))
        .join('/');
  }

  static String _canonicalQuery(Map<String, List<String>> query) {
    final List<(String, String)> pairs =
        [
          for (final MapEntry<String, List<String>> entry in query.entries)
            for (final String value in entry.value)
              (encodeComponent(entry.key), encodeComponent(value)),
        ]..sort((a, b) {
          final int byKey = a.$1.compareTo(b.$1);
          return byKey != 0 ? byKey : a.$2.compareTo(b.$2);
        });
    return pairs
        .map(((String, String) pair) => '${pair.$1}=${pair.$2}')
        .join('&');
  }

  /// Percent-encodes [value] as SigV4 requires: every byte but the RFC 3986
  /// unreserved characters (`A-Z a-z 0-9 - . _ ~`) becomes `%XX`, upper-case.
  ///
  /// Apply it to one path segment, or to one query name or value, never to a
  /// whole path (it would encode the slashes).
  static String encodeComponent(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in utf8.encode(value)) {
      final bool unreserved =
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x2E ||
          byte == 0x5F ||
          byte == 0x7E;
      if (unreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }
}
