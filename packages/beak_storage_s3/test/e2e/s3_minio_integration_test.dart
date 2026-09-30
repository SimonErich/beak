@Tags(['e2e'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:test/test.dart';

/// The MinIO endpoint under test, matching `docker-compose.yml` /
/// `.env.example` defaults; override via `BEAK_S3_ENDPOINT`.
final Uri endpoint = Uri.parse(
  Platform.environment['BEAK_S3_ENDPOINT'] ?? 'http://localhost:29000',
);

final BeakS3Config config = BeakS3Config(
  endpoint: endpoint,
  bucket: Platform.environment['BEAK_S3_BUCKET'] ?? 'beak-uploads',
  accessKey: Platform.environment['BEAK_S3_ACCESS_KEY'] ?? 'beak',
  secretKey: Platform.environment['BEAK_S3_SECRET_KEY'] ?? 'beaksecret',
  region: Platform.environment['BEAK_S3_REGION'] ?? 'us-east-1',
  usePathStyle: true,
);

/// Fetches [url] and returns status code, body bytes, and content type.
Future<(int, Uint8List, String?)> httpGet(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return (
      response.statusCode,
      builder.takeBytes(),
      response.headers.contentType?.mimeType,
    );
  } finally {
    client.close();
  }
}

Future<bool> minioIsReachable() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(
      endpoint.replace(path: '/minio/health/live'),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode == 200;
  } on Object {
    return false;
  } finally {
    client.close();
  }
}

void main() {
  late bool reachable;

  setUpAll(() async {
    reachable = await minioIsReachable();
  });

  /// Skips the calling test with a clear message when MinIO is down; the
  /// phase gate runs with services up, so these tests then run for real.
  bool guarded() {
    if (!reachable) {
      markTestSkipped(
        'MinIO is unreachable at $endpoint — start it with `melos run up`.',
      );
      return false;
    }
    return true;
  }

  group('S3StorageDriver against MinIO', () {
    final driver = S3StorageDriver(config);
    final runId = DateTime.now().millisecondsSinceEpoch;
    final path = 'integration/$runId';
    final key = '$path/photo.png';
    final bytes = Uint8List.fromList(List.generate(64, (i) => i * 3 % 251));

    tearDownAll(() async {
      if (!reachable) {
        return;
      }
      if (await driver.exists(key)) {
        await driver.delete(key);
      }
    });

    test('put stores the object and reports key, url, and size', () async {
      if (!guarded()) {
        return;
      }
      final stored = await driver.put(
        BeakUpload(filename: 'photo.png', mimeType: 'image/png', bytes: bytes),
        path: path,
      );
      expect(stored.key, key);
      expect(stored.sizeInBytes, bytes.length);
      expect(stored.mimeType, 'image/png');
      expect(stored.url, Uri.parse('$endpoint/${config.bucket}/$key'));
    });

    test('get round-trips the stored bytes', () async {
      if (!guarded()) {
        return;
      }
      expect(await driver.get(key), bytes);
    });

    test('exists sees the stored object', () async {
      if (!guarded()) {
        return;
      }
      expect(await driver.exists(key), isTrue);
      expect(await driver.exists('$path/absent.png'), isFalse);
    });

    test(
      'the public URL serves the bytes with the stored content type',
      () async {
        if (!guarded()) {
          return;
        }
        final (status, body, contentType) = await httpGet(
          await driver.url(key),
        );
        expect(status, 200);
        expect(body, bytes);
        expect(contentType, 'image/png');
      },
    );

    test('a presigned URL serves the bytes', () async {
      if (!guarded()) {
        return;
      }
      final url = await driver.url(key, expiresIn: const Duration(minutes: 5));
      expect(url.queryParameters, contains('X-Amz-Signature'));
      final (status, body, _) = await httpGet(url);
      expect(status, 200);
      expect(body, bytes);
    });

    test('get of a missing key throws not-found', () async {
      if (!guarded()) {
        return;
      }
      await expectLater(
        driver.get('$path/absent.png'),
        throwsA(
          isA<BeakStorageException>().having(
            (e) => e.message,
            'message',
            contains('No file is stored under'),
          ),
        ),
      );
    });

    test(
      'delete removes the object; deleting again throws not-found',
      () async {
        if (!guarded()) {
          return;
        }
        await driver.delete(key);
        expect(await driver.exists(key), isFalse);
        await expectLater(
          driver.delete(key),
          throwsA(isA<BeakStorageException>()),
        );
      },
    );

    test(
      'a key with spaces, accents and reserved characters round-trips',
      () async {
        if (!guarded()) {
          return;
        }
        final upload = BeakUpload(
          filename: 'ä b+(1)!.png',
          mimeType: 'image/png',
          bytes: bytes,
        );
        final stored = await driver.put(upload, path: '$path/odd keys');
        addTearDown(() => driver.delete(stored.key));
        expect(await driver.exists(stored.key), isTrue);
        expect(await driver.get(stored.key), bytes);
        final url = await driver.url(
          stored.key,
          expiresIn: const Duration(minutes: 5),
        );
        final (status, body, _) = await httpGet(url);
        expect(status, 200);
        expect(body, bytes);
      },
    );

    test('a missing bucket is an error, not a missing file', () async {
      if (!guarded()) {
        return;
      }
      final elsewhere = S3StorageDriver(
        BeakS3Config(
          endpoint: endpoint,
          bucket: 'beak-no-such-bucket',
          accessKey: config.accessKey,
          secretKey: config.secretKey,
          region: config.region,
          usePathStyle: true,
        ),
      );
      await expectLater(
        elsewhere.get('$path/photo.png'),
        throwsA(
          isA<BeakStorageException>().having(
            (e) => e.message,
            'message',
            contains('NoSuchBucket'),
          ),
        ),
      );
    });

    test('bad credentials surface as BeakStorageException', () async {
      if (!guarded()) {
        return;
      }
      final unauthorized = S3StorageDriver(
        BeakS3Config(
          endpoint: endpoint,
          bucket: config.bucket,
          accessKey: 'wrong',
          secretKey: 'credentials',
          region: config.region,
          usePathStyle: true,
        ),
      );
      await expectLater(
        unauthorized.put(
          BeakUpload(filename: 'nope.png', mimeType: 'image/png', bytes: bytes),
          path: path,
        ),
        throwsA(isA<BeakStorageException>()),
      );
    });
  });
}
