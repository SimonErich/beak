import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 's3_object_client.dart';
import 's3_response_exception.dart';
import 'sigv4_signer.dart';

/// The production [S3ObjectClient]: S3's REST API over `package:http`, signed
/// with AWS Signature Version 4.
///
/// It speaks to AWS S3, MinIO and other S3-compatible stores, and it needs
/// nothing beyond `package:http` and `package:crypto`. [S3StorageDriver]
/// constructs one from its [BeakS3Config] when no test client is injected, so
/// application code rarely instantiates it directly.
///
/// The endpoint's scheme selects TLS, and its host and optional port address
/// the server; a path on the endpoint is ignored. [BeakS3Config.usePathStyle]
/// chooses path-style (`endpoint/bucket/key`, which MinIO needs) or
/// virtual-host (`bucket.endpoint/key`) addressing. Each object is written in
/// one `PUT`, which S3 accepts up to 5 GiB.
///
/// A failing response throws an [S3ResponseException]; a failure before any
/// response (DNS, connection reset) throws whatever `package:http` throws.
///
/// ```dart
/// final client = HttpS3ObjectClient(BeakS3Config(
///   endpoint: Uri.parse('http://localhost:29000'),
///   bucket: 'uploads',
///   accessKey: 'minioadmin',
///   secretKey: 'minioadmin',
///   region: 'us-east-1',
///   usePathStyle: true,
/// ));
/// ```
final class HttpS3ObjectClient implements S3ObjectClient {
  /// Creates a client for the endpoint and credentials in [config].
  ///
  /// [httpClient] replaces the transport (the default is a new
  /// `http.Client`), and [clock] the time requests are signed at (the default
  /// is [DateTime.now]); tests use both.
  HttpS3ObjectClient(
    BeakS3Config config, {
    http.Client? httpClient,
    DateTime Function()? clock,
  }) : _config = config,
       _signer = SigV4Signer(
         accessKey: config.accessKey,
         secretKey: config.secretKey,
         region: config.region,
       ),
       _http = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final BeakS3Config _config;
  final SigV4Signer _signer;
  final http.Client _http;
  final DateTime Function() _clock;

  /// Closes the underlying HTTP client and its idle connections.
  void close() => _http.close();

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final http.Response response = await _send(
      'PUT',
      _urlFor(bucket, key),
      body: bytes,
      contentType: contentType,
    );
    _requireSuccess(response);
  }

  @override
  Future<Uint8List?> getObject({
    required String bucket,
    required String key,
  }) async {
    final http.Response response = await _send('GET', _urlFor(bucket, key));
    if (_isSuccess(response)) {
      return response.bodyBytes;
    }
    final S3ResponseException error = _exceptionOf(response);
    if (_isMissingObject(error)) {
      return null;
    }
    throw error;
  }

  @override
  Future<void> removeObject({
    required String bucket,
    required String key,
  }) async {
    final http.Response response = await _send('DELETE', _urlFor(bucket, key));
    if (_isSuccess(response)) {
      return;
    }
    final S3ResponseException error = _exceptionOf(response);
    if (!_isMissingObject(error)) {
      throw error;
    }
  }

  @override
  Future<bool> objectExists({
    required String bucket,
    required String key,
  }) async {
    final http.Response response = await _send('HEAD', _urlFor(bucket, key));
    if (_isSuccess(response)) {
      return true;
    }
    final S3ResponseException error = _exceptionOf(response);
    if (_isMissingObject(error)) {
      return false;
    }
    throw error;
  }

  @override
  Future<Uri> presignedGetUrl({
    required String bucket,
    required String key,
    required Duration expiresIn,
  }) async => _signer.presignUrl(
    method: 'GET',
    url: _urlFor(bucket, key),
    expiresInSeconds: expiresIn.inSeconds,
    timestamp: _clock(),
  );

  /// The URL of [key] in [bucket], addressed the way the config asks.
  ///
  /// Built from an already-encoded string so the path on the wire is exactly
  /// the one the signature covers.
  Uri _urlFor(String bucket, String key) {
    final Uri endpoint = _config.endpoint;
    final String encodedKey = key
        .split('/')
        .map(SigV4Signer.encodeComponent)
        .join('/');
    final bool pathStyle = _config.usePathStyle;
    final String origin = Uri(
      scheme: endpoint.scheme,
      host: pathStyle ? endpoint.host : '$bucket.${endpoint.host}',
      port: endpoint.hasPort ? endpoint.port : null,
    ).toString();
    final String path = pathStyle
        ? '/${SigV4Signer.encodeComponent(bucket)}/$encodedKey'
        : '/$encodedKey';
    return Uri.parse('$origin$path');
  }

  Future<http.Response> _send(
    String method,
    Uri url, {
    Uint8List? body,
    String? contentType,
  }) async {
    final Uint8List payload = body ?? Uint8List(0);
    final String payloadSha256 = sha256.convert(payload).toString();
    final Map<String, String> signed = _signer.signHeaders(
      method: method,
      url: url,
      headers: {
        'host': SigV4Signer.hostHeaderOf(url),
        'x-amz-content-sha256': payloadSha256,
        'content-type': ?contentType,
      },
      payloadSha256: payloadSha256,
      timestamp: _clock(),
    );
    // The HTTP stack writes `Host` itself, from the URL, in the same form
    // that was signed; setting it here would override that.
    final http.Request request = http.Request(method, url)
      ..headers.addAll(signed)
      ..headers.remove('host')
      ..bodyBytes = payload;
    return http.Response.fromStream(await _http.send(request));
  }

  static bool _isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  static void _requireSuccess(http.Response response) {
    if (!_isSuccess(response)) {
      throw _exceptionOf(response);
    }
  }

  static S3ResponseException _exceptionOf(http.Response response) =>
      S3ResponseException.fromResponse(
        statusCode: response.statusCode,
        body: utf8.decode(response.bodyBytes, allowMalformed: true),
      );

  /// Whether [error] means the object is not there, rather than that the
  /// request failed.
  ///
  /// A `HEAD` answer has no body, so the status is the signal; a missing
  /// bucket is a 404 too, but it is a configuration error and must surface.
  static bool _isMissingObject(S3ResponseException error) =>
      error.statusCode == 404 && error.code != 'NoSuchBucket';
}
