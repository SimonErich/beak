import 'dart:io';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:beak_storage_s3/src/sigv4_signer.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// The moment the injected clock reports, matching AWS' published examples.
final DateTime fixedNow = DateTime.utc(2013, 5, 24);

/// Every request the client sent, in order.
final class RecordedRequests {
  final List<http.Request> sent = [];

  http.Request get single => sent.single;
}

/// The S3 error document a real endpoint answers with.
String s3ErrorXml(String code, String message) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Error><Code>$code</Code><Message>$message</Message>'
    '<BucketName>beak-uploads</BucketName><RequestId>4442587FB7D0A2F9</RequestId>'
    '</Error>';

/// The signature the client is expected to have sent for [request].
///
/// Rebuilds the signed headers from the request itself, so it proves the
/// request was signed over what was actually sent.
String expectedAuthorization(
  http.Request request, {
  SigV4Signer signer = const SigV4Signer(
    accessKey: 'ak',
    secretKey: 'sk',
    region: 'us-east-1',
  ),
}) {
  final String authorization = request.headers['authorization'] ?? '';
  final RegExpMatch? match = RegExp(
    r'SignedHeaders=([^,]+),',
  ).firstMatch(authorization);
  final List<String> signedNames = (match?.group(1) ?? '').split(';');
  final Map<String, String> headers = {
    for (final String name in signedNames)
      name: name == 'host'
          ? SigV4Signer.hostHeaderOf(request.url)
          : request.headers[name] ?? '',
  }..remove('x-amz-date');
  return signer.signHeaders(
        method: request.method,
        url: request.url,
        headers: headers,
        payloadSha256: request.headers['x-amz-content-sha256'] ?? '',
        timestamp: fixedNow,
      )['authorization'] ??
      '';
}

void main() {
  final BeakS3Config config = BeakS3Config(
    endpoint: Uri.parse('http://localhost:29000'),
    bucket: 'beak-uploads',
    accessKey: 'ak',
    secretKey: 'sk',
    region: 'us-east-1',
    usePathStyle: true,
  );
  final Uint8List bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  late RecordedRequests recorded;
  late http.Response Function(http.Request request) respond;
  late HttpS3ObjectClient client;

  HttpS3ObjectClient clientFor(BeakS3Config forConfig) => HttpS3ObjectClient(
    forConfig,
    httpClient: MockClient((http.Request request) async {
      recorded.sent.add(request);
      final http.Response response = respond(request);
      return response;
    }),
    clock: () => fixedNow,
  );

  setUp(() {
    recorded = RecordedRequests();
    respond = (_) => http.Response('', 200);
    client = clientFor(config);
  });

  group('HttpS3ObjectClient', () {
    group('putObject', () {
      test('PUTs the bytes to the path-style URL with a signed payload', () async {
        await client.putObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          bytes: bytes,
          contentType: 'image/png',
        );
        final http.Request request = recorded.single;
        expect(request.method, 'PUT');
        expect(
          request.url.toString(),
          'http://localhost:29000/beak-uploads/products/photo.png',
        );
        expect(request.bodyBytes, bytes);
        expect(request.headers['content-type'], 'image/png');
        expect(
          request.headers['x-amz-content-sha256'],
          sha256.convert(bytes).toString(),
        );
        expect(request.headers['x-amz-date'], '20130524T000000Z');
        expect(
          request.headers['authorization'],
          startsWith(
            'AWS4-HMAC-SHA256 Credential=ak/20130524/us-east-1/s3/aws4_request,',
          ),
        );
        expect(
          request.headers['authorization'],
          contains(
            'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,',
          ),
        );
        expect(
          request.headers['authorization'],
          expectedAuthorization(request),
        );
      });

      test(
        'does not set the Host header itself, the HTTP stack does',
        () async {
          await client.putObject(
            bucket: 'beak-uploads',
            key: 'a.png',
            bytes: bytes,
            contentType: 'image/png',
          );
          expect(recorded.single.headers, isNot(contains('host')));
        },
      );

      test('percent-encodes the key the way S3 canonicalizes it', () async {
        await client.putObject(
          bucket: 'beak-uploads',
          key: 'products/a b/é+(1)!.png',
          bytes: bytes,
          contentType: 'image/png',
        );
        expect(
          recorded.single.url.path,
          '/beak-uploads/products/a%20b/%C3%A9%2B%281%29%21.png',
        );
        expect(
          recorded.single.headers['authorization'],
          expectedAuthorization(recorded.single),
        );
      });

      test('addresses the bucket in the host for virtual-host style', () async {
        final HttpS3ObjectClient aws = clientFor(
          BeakS3Config(
            endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
            bucket: 'beak-uploads',
            accessKey: 'ak',
            secretKey: 'sk',
            region: 'us-east-1',
          ),
        );
        await aws.putObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          bytes: bytes,
          contentType: 'image/png',
        );
        final http.Request request = recorded.single;
        expect(
          request.url.toString(),
          'https://beak-uploads.s3.eu-central-1.amazonaws.com/products/photo.png',
        );
        expect(
          request.headers['authorization'],
          expectedAuthorization(request),
        );
      });

      test(
        'throws the S3 error, rather than reporting a failed upload as done',
        () {
          respond = (_) =>
              http.Response(s3ErrorXml('AccessDenied', 'Access Denied'), 403);
          return expectLater(
            client.putObject(
              bucket: 'beak-uploads',
              key: 'products/photo.png',
              bytes: bytes,
              contentType: 'image/png',
            ),
            throwsA(
              isA<S3ResponseException>()
                  .having((e) => e.statusCode, 'statusCode', 403)
                  .having((e) => e.code, 'code', 'AccessDenied')
                  .having((e) => e.message, 'message', 'Access Denied'),
            ),
          );
        },
      );

      test('lets a transport failure through', () {
        final HttpS3ObjectClient broken = HttpS3ObjectClient(
          config,
          httpClient: MockClient(
            (_) async => throw http.ClientException('connection reset'),
          ),
          clock: () => fixedNow,
        );
        return expectLater(
          broken.putObject(
            bucket: 'beak-uploads',
            key: 'a.png',
            bytes: bytes,
            contentType: 'image/png',
          ),
          throwsA(isA<http.ClientException>()),
        );
      });
    });

    group('getObject', () {
      test('GETs the object and returns its bytes', () async {
        respond = (_) => http.Response.bytes(bytes, 200);
        final Uint8List? got = await client.getObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
        );
        expect(got, bytes);
        final http.Request request = recorded.single;
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://localhost:29000/beak-uploads/products/photo.png',
        );
        expect(
          request.headers['x-amz-content-sha256'],
          sha256.convert(const <int>[]).toString(),
        );
        expect(
          request.headers['authorization'],
          expectedAuthorization(request),
        );
      });

      test('returns null when S3 answers NoSuchKey', () async {
        respond = (_) => http.Response(
          s3ErrorXml('NoSuchKey', 'The specified key does not exist.'),
          404,
        );
        expect(
          await client.getObject(bucket: 'beak-uploads', key: 'missing.png'),
          isNull,
        );
      });

      test('returns null for a 404 that carries no error document', () async {
        respond = (_) => http.Response('', 404);
        expect(
          await client.getObject(bucket: 'beak-uploads', key: 'missing.png'),
          isNull,
        );
      });

      test(
        'throws for a missing bucket, which is a config error, not a missing file',
        () {
          respond = (_) => http.Response(
            s3ErrorXml('NoSuchBucket', 'The specified bucket does not exist'),
            404,
          );
          return expectLater(
            client.getObject(bucket: 'beak-uploads', key: 'a.png'),
            throwsA(
              isA<S3ResponseException>().having(
                (e) => e.code,
                'code',
                'NoSuchBucket',
              ),
            ),
          );
        },
      );

      test('throws an S3 error that is not a missing object', () {
        respond = (_) => http.Response(
          s3ErrorXml('InternalError', 'We encountered an internal error.'),
          500,
        );
        return expectLater(
          client.getObject(bucket: 'beak-uploads', key: 'a.png'),
          throwsA(
            isA<S3ResponseException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });
    });

    group('removeObject', () {
      test('DELETEs the key', () async {
        respond = (_) => http.Response('', 204);
        await client.removeObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
        );
        final http.Request request = recorded.single;
        expect(request.method, 'DELETE');
        expect(
          request.url.toString(),
          'http://localhost:29000/beak-uploads/products/photo.png',
        );
        expect(
          request.headers['authorization'],
          expectedAuthorization(request),
        );
      });

      test('is a no-op when the store answers NoSuchKey', () async {
        respond = (_) => http.Response(s3ErrorXml('NoSuchKey', 'gone'), 404);
        await client.removeObject(bucket: 'beak-uploads', key: 'a.png');
        expect(recorded.sent, hasLength(1));
      });

      test('throws an S3 error that is not a missing object', () {
        respond = (_) =>
            http.Response(s3ErrorXml('AccessDenied', 'Access Denied'), 403);
        return expectLater(
          client.removeObject(bucket: 'beak-uploads', key: 'a.png'),
          throwsA(isA<S3ResponseException>()),
        );
      });
    });

    group('objectExists', () {
      test('is true when HEAD answers 200', () async {
        expect(
          await client.objectExists(bucket: 'beak-uploads', key: 'photo.png'),
          isTrue,
        );
        final http.Request request = recorded.single;
        expect(request.method, 'HEAD');
        expect(
          request.headers['authorization'],
          expectedAuthorization(request),
        );
      });

      test('is false when HEAD answers 404', () async {
        respond = (_) => http.Response('', 404);
        expect(
          await client.objectExists(bucket: 'beak-uploads', key: 'missing.png'),
          isFalse,
        );
      });

      test('throws an S3 error that is not a missing object', () {
        respond = (_) => http.Response('', 403);
        return expectLater(
          client.objectExists(bucket: 'beak-uploads', key: 'photo.png'),
          throwsA(
            isA<S3ResponseException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      });
    });

    group('presignedGetUrl', () {
      test('signs locally, sending nothing', () async {
        final Uri url = await client.presignedGetUrl(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          expiresIn: const Duration(minutes: 5),
        );
        expect(recorded.sent, isEmpty);
        expect(url.scheme, 'http');
        expect(url.host, 'localhost');
        expect(url.port, 29000);
        expect(url.path, '/beak-uploads/products/photo.png');
        expect(url.queryParameters['X-Amz-Expires'], '300');
        expect(url.queryParameters['X-Amz-Date'], '20130524T000000Z');
        expect(
          url.queryParameters['X-Amz-Credential'],
          'ak/20130524/us-east-1/s3/aws4_request',
        );
        expect(url.queryParameters['X-Amz-SignedHeaders'], 'host');
      });

      test('carries the signature the signer computes for that URL', () async {
        final Uri url = await client.presignedGetUrl(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          expiresIn: const Duration(minutes: 5),
        );
        final Uri expected =
            const SigV4Signer(
              accessKey: 'ak',
              secretKey: 'sk',
              region: 'us-east-1',
            ).presignUrl(
              method: 'GET',
              url: Uri.parse(
                'http://localhost:29000/beak-uploads/products/photo.png',
              ),
              expiresInSeconds: 300,
              timestamp: fixedNow,
            );
        expect(url, expected);
      });

      test('uses TLS and the implied port for an https endpoint', () async {
        final Uri url =
            await clientFor(
              BeakS3Config(
                endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
                bucket: 'beak-uploads',
                accessKey: 'ak',
                secretKey: 'sk',
                region: 'eu-central-1',
              ),
            ).presignedGetUrl(
              bucket: 'beak-uploads',
              key: 'products/photo.png',
              expiresIn: const Duration(minutes: 5),
            );
        expect(url.scheme, 'https');
        expect(url.host, 'beak-uploads.s3.eu-central-1.amazonaws.com');
        expect(url.hasPort, isFalse);
        expect(
          url.queryParameters['X-Amz-Credential'],
          contains('eu-central-1'),
        );
      });

      test('rejects a lifetime S3 would refuse', () {
        return expectLater(
          client.presignedGetUrl(
            bucket: 'beak-uploads',
            key: 'a.png',
            expiresIn: const Duration(days: 8),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('close', () {
      test('closes the HTTP client it was given', () {
        final _ClosableClient closable = _ClosableClient();
        HttpS3ObjectClient(config, httpClient: closable).close();
        expect(closable.closed, isTrue);
      });
    });
  });

  group('S3ResponseException', () {
    Future<S3ResponseException> failWith(http.Response response) async {
      respond = (_) => response;
      try {
        await client.getObject(bucket: 'beak-uploads', key: 'a.png');
      } on S3ResponseException catch (error) {
        return error;
      }
      throw StateError('expected the request to fail');
    }

    test('reads the code and message from the error document', () async {
      final S3ResponseException error = await failWith(
        http.Response(
          s3ErrorXml(
            'SignatureDoesNotMatch',
            'The request signature we calculated does not match',
          ),
          403,
        ),
      );
      expect(error.statusCode, 403);
      expect(error.code, 'SignatureDoesNotMatch');
      expect(
        error.message,
        'The request signature we calculated does not match',
      );
      expect(
        error.toString(),
        'S3ResponseException(403 SignatureDoesNotMatch): '
        'The request signature we calculated does not match',
      );
    });

    test('unescapes the predefined XML entities in the message', () async {
      final S3ResponseException error = await failWith(
        http.Response(
          s3ErrorXml(
            'InvalidArgument',
            'a &lt;b&gt; &amp; &quot;c&quot; &apos;d&apos;',
          ),
          400,
        ),
      );
      expect(error.message, 'a <b> & "c" \'d\'');
    });

    test('keeps the status when the body is not an error document', () async {
      final S3ResponseException error = await failWith(
        http.Response('<html>Bad Gateway</html>', 502),
      );
      expect(error.statusCode, 502);
      expect(error.code, isNull);
      expect(error.message, isNull);
      expect(error.toString(), 'S3ResponseException(502)');
    });

    test('reads an escaped entity as text, not as a second escape', () async {
      final S3ResponseException error = await failWith(
        http.Response(s3ErrorXml('InvalidArgument', '&amp;lt; stays'), 400),
      );
      expect(error.message, '&lt; stays');
    });

    test('keeps the status when the body is empty', () async {
      final S3ResponseException error = await failWith(http.Response('', 403));
      expect(error.code, isNull);
      expect(error.toString(), 'S3ResponseException(403)');
    });

    test('reads a code without a message', () async {
      final S3ResponseException error = await failWith(
        http.Response('<Error><Code>SlowDown</Code></Error>', 503),
      );
      expect(error.code, 'SlowDown');
      expect(error.message, isNull);
      expect(error.toString(), 'S3ResponseException(503 SlowDown)');
    });
  });

  group('over a real socket', () {
    late HttpServer server;
    late FakeS3Server fake;
    late HttpS3ObjectClient real;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      fake = FakeS3Server(server);
      real = HttpS3ObjectClient(
        BeakS3Config(
          endpoint: Uri.parse('http://localhost:${server.port}'),
          bucket: 'beak-uploads',
          accessKey: 'ak',
          secretKey: 'sk',
          region: 'us-east-1',
          usePathStyle: true,
        ),
      );
    });

    tearDown(() async {
      real.close();
      await server.close(force: true);
    });

    test(
      'a driver round trip is accepted by a server that verifies each signature',
      () async {
        final S3StorageDriver driver = S3StorageDriver(
          BeakS3Config(
            endpoint: Uri.parse('http://localhost:${server.port}'),
            bucket: 'beak-uploads',
            accessKey: 'ak',
            secretKey: 'sk',
            region: 'us-east-1',
            usePathStyle: true,
          ),
          client: real,
        );
        final BeakStoredFile stored = await driver.put(
          BeakUpload(filename: 'a b.png', mimeType: 'image/png', bytes: bytes),
          path: 'products',
        );
        expect(stored.key, 'products/a b.png');
        expect(await driver.exists(stored.key), isTrue);
        expect(await driver.get(stored.key), bytes);
        await driver.delete(stored.key);
        expect(await driver.exists(stored.key), isFalse);
        await expectLater(
          driver.get(stored.key),
          throwsA(isA<BeakStorageException>()),
        );
        expect(fake.verifiedRequests, 7);
        expect(fake.rejectedRequests, isEmpty);
      },
    );

    test('a bad secret is refused and surfaces as the S3 error', () async {
      final HttpS3ObjectClient wrong = HttpS3ObjectClient(
        BeakS3Config(
          endpoint: Uri.parse('http://localhost:${server.port}'),
          bucket: 'beak-uploads',
          accessKey: 'ak',
          secretKey: 'not-the-secret',
          region: 'us-east-1',
          usePathStyle: true,
        ),
      );
      addTearDown(wrong.close);
      await expectLater(
        wrong.putObject(
          bucket: 'beak-uploads',
          key: 'a.png',
          bytes: bytes,
          contentType: 'image/png',
        ),
        throwsA(
          isA<S3ResponseException>().having(
            (e) => e.code,
            'code',
            'SignatureDoesNotMatch',
          ),
        ),
      );
    });
  });
}

/// An [http.BaseClient] that records being closed.
final class _ClosableClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}

/// A tiny in-memory S3 that recomputes every request's SigV4 signature from
/// what it received, so the Host header dart:io really sent is part of the
/// check.
final class FakeS3Server {
  FakeS3Server(HttpServer server) {
    server.listen(_handle);
  }

  static const SigV4Signer _signer = SigV4Signer(
    accessKey: 'ak',
    secretKey: 'sk',
    region: 'us-east-1',
  );

  final Map<String, Uint8List> _objects = {};

  /// How many requests carried a signature that matched.
  int verifiedRequests = 0;

  /// The `METHOD path` of every request whose signature did not match.
  final List<String> rejectedRequests = [];

  Future<void> _handle(HttpRequest request) async {
    final BytesBuilder body = BytesBuilder(copy: false);
    await request.forEach(body.add);
    final Uint8List payload = body.takeBytes();
    final String path = Uri.decodeComponent(request.uri.path);
    if (!_signatureMatches(request, payload)) {
      rejectedRequests.add('${request.method} ${request.uri.path}');
      request.response
        ..statusCode = 403
        ..write(s3ErrorXml('SignatureDoesNotMatch', 'bad signature'));
      await request.response.close();
      return;
    }
    verifiedRequests++;
    final Uint8List? stored = _objects[path];
    switch (request.method) {
      case 'PUT':
        _objects[path] = payload;
        request.response.statusCode = 200;
      case 'GET':
        if (stored == null) {
          request.response
            ..statusCode = 404
            ..write(
              s3ErrorXml('NoSuchKey', 'The specified key does not exist.'),
            );
        } else {
          request.response
            ..statusCode = 200
            ..add(stored);
        }
      case 'HEAD':
        request.response.statusCode = stored == null ? 404 : 200;
      case 'DELETE':
        _objects.remove(path);
        request.response.statusCode = 204;
      default:
        request.response.statusCode = 405;
    }
    await request.response.close();
  }

  bool _signatureMatches(HttpRequest request, Uint8List payload) {
    final String authorization = request.headers.value('authorization') ?? '';
    final RegExpMatch? match = RegExp(
      r'SignedHeaders=([^,]+),',
    ).firstMatch(authorization);
    final List<String> signedNames = (match?.group(1) ?? '').split(';');
    final Map<String, String> headers = {
      for (final String name in signedNames)
        if (name != 'x-amz-date') name: request.headers.value(name) ?? '',
    };
    final String claimedPayload =
        request.headers.value('x-amz-content-sha256') ?? '';
    if (claimedPayload != sha256.convert(payload).toString()) {
      return false;
    }
    final String? amzDate = request.headers.value('x-amz-date');
    if (amzDate == null) {
      return false;
    }
    final Map<String, String> expected = _signer.signHeaders(
      method: request.method,
      url: Uri.parse('http://${request.headers.value('host')}${request.uri}'),
      headers: headers,
      payloadSha256: claimedPayload,
      timestamp: DateTime.parse(amzDate),
    );
    return expected['authorization'] == authorization;
  }
}
