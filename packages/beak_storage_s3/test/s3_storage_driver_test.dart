import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:test/test.dart';

/// A recorded call against the [FakeS3ObjectClient].
final class RecordedCall {
  RecordedCall(this.operation, this.bucket, this.key);

  final String operation;
  final String bucket;
  final String key;
}

/// In-memory [S3ObjectClient] recording every call, with failure knobs.
final class FakeS3ObjectClient implements S3ObjectClient {
  final Map<String, Uint8List> objects = {};
  final Map<String, String> contentTypes = {};
  final List<RecordedCall> calls = [];

  /// When set, every method throws this error instead of executing.
  Object? failure;

  void _record(String operation, String bucket, String key) {
    calls.add(RecordedCall(operation, bucket, key));
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _record('put', bucket, key);
    objects[key] = bytes;
    contentTypes[key] = contentType;
  }

  @override
  Future<Uint8List?> getObject({
    required String bucket,
    required String key,
  }) async {
    _record('get', bucket, key);
    return objects[key];
  }

  @override
  Future<void> removeObject({
    required String bucket,
    required String key,
  }) async {
    _record('remove', bucket, key);
    objects.remove(key);
  }

  @override
  Future<bool> objectExists({
    required String bucket,
    required String key,
  }) async {
    _record('exists', bucket, key);
    return objects.containsKey(key);
  }

  @override
  Future<Uri> presignedGetUrl({
    required String bucket,
    required String key,
    required Duration expiresIn,
  }) async {
    _record('presign', bucket, key);
    return Uri.parse(
      'http://signed.example.com/$bucket/$key?expires=${expiresIn.inSeconds}',
    );
  }
}

void main() {
  final endpoint = Uri.parse('http://localhost:29000');
  final config = BeakS3Config(
    endpoint: endpoint,
    bucket: 'beak-uploads',
    accessKey: 'ak',
    secretKey: 'sk',
    region: 'us-east-1',
    usePathStyle: true,
  );
  final upload = BeakUpload(
    filename: 'photo.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  late FakeS3ObjectClient client;
  late S3StorageDriver driver;

  setUp(() {
    client = FakeS3ObjectClient();
    driver = S3StorageDriver(config, client: client);
  });

  group('S3StorageDriver', () {
    test('identifies as the "s3" driver', () {
      expect(driver.id, 's3');
    });

    group('put', () {
      test('uploads to the bucket under path/filename with the '
          'declared content type', () async {
        final stored = await driver.put(upload, path: 'products');
        expect(client.calls.single.operation, 'put');
        expect(client.calls.single.bucket, 'beak-uploads');
        expect(client.calls.single.key, 'products/photo.png');
        expect(client.objects['products/photo.png'], upload.bytes);
        expect(client.contentTypes['products/photo.png'], 'image/png');
        expect(stored.key, 'products/photo.png');
        expect(stored.sizeInBytes, 3);
        expect(stored.mimeType, 'image/png');
      });

      test('builds a path-style endpoint URL when no public base URL is '
          'configured', () async {
        final stored = await driver.put(upload, path: 'products');
        expect(
          stored.url,
          Uri.parse('http://localhost:29000/beak-uploads/products/photo.png'),
        );
      });

      test('builds a virtual-host URL when path style is off', () async {
        final virtualHost = S3StorageDriver(
          BeakS3Config(
            endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
            bucket: 'beak-uploads',
            accessKey: 'ak',
            secretKey: 'sk',
            region: 'eu-central-1',
          ),
          client: client,
        );
        final stored = await virtualHost.put(upload, path: 'products');
        expect(
          stored.url,
          Uri.parse(
            'https://beak-uploads.s3.eu-central-1.amazonaws.com'
            '/products/photo.png',
          ),
        );
      });

      test('prefers the configured public base URL', () async {
        final cdn = S3StorageDriver(
          BeakS3Config(
            endpoint: endpoint,
            bucket: 'beak-uploads',
            accessKey: 'ak',
            secretKey: 'sk',
            region: 'us-east-1',
            usePathStyle: true,
            publicBaseUrl: Uri.parse('https://cdn.example.com/uploads'),
          ),
          client: client,
        );
        final stored = await cdn.put(upload, path: 'products');
        expect(
          stored.url,
          Uri.parse('https://cdn.example.com/uploads/products/photo.png'),
        );
      });

      test('rejects traversal filenames before touching the client', () async {
        final evil = BeakUpload(
          filename: '../evil.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        );
        await expectLater(
          driver.put(evil, path: 'products'),
          throwsA(isA<BeakStorageException>()),
        );
        expect(client.calls, isEmpty);
      });

      test('maps client failures to BeakStorageException', () async {
        client.failure = Exception('boom');
        await expectLater(
          driver.put(upload, path: 'products'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              allOf(contains('put'), contains('products/photo.png')),
            ),
          ),
        );
      });
    });

    group('get', () {
      test('returns the stored bytes', () async {
        await driver.put(upload, path: 'products');
        expect(await driver.get('products/photo.png'), upload.bytes);
      });

      test('throws not-found for a missing key', () async {
        await expectLater(
          driver.get('products/missing.png'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              contains('No file is stored under "products/missing.png"'),
            ),
          ),
        );
      });

      test('rejects malformed keys before touching the client', () async {
        await expectLater(
          driver.get('/absolute.png'),
          throwsA(isA<BeakStorageException>()),
        );
        expect(client.calls, isEmpty);
      });

      test('maps client failures to BeakStorageException', () async {
        client.failure = StateError('socket closed');
        await expectLater(
          driver.get('products/photo.png'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              allOf(contains('get'), contains('socket closed')),
            ),
          ),
        );
      });
    });

    group('delete', () {
      test('removes an existing object', () async {
        await driver.put(upload, path: 'products');
        await driver.delete('products/photo.png');
        expect(client.objects, isEmpty);
      });

      test(
        'throws not-found without removing when the key is missing',
        () async {
          await expectLater(
            driver.delete('products/missing.png'),
            throwsA(
              isA<BeakStorageException>().having(
                (e) => e.message,
                'message',
                contains('No file is stored under "products/missing.png"'),
              ),
            ),
          );
          expect(
            client.calls.map((c) => c.operation),
            isNot(contains('remove')),
          );
        },
      );
    });

    group('url', () {
      test('returns the public URL when no expiry is requested', () async {
        expect(
          await driver.url('products/photo.png'),
          Uri.parse('http://localhost:29000/beak-uploads/products/photo.png'),
        );
        expect(client.calls, isEmpty);
      });

      test('presigns when an expiry is requested', () async {
        final url = await driver.url(
          'products/photo.png',
          expiresIn: const Duration(minutes: 5),
        );
        expect(client.calls.single.operation, 'presign');
        expect(url.queryParameters['expires'], '300');
      });

      test('rejects malformed keys', () async {
        await expectLater(
          driver.url('a//b.png'),
          throwsA(isA<BeakStorageException>()),
        );
      });
    });

    group('exists', () {
      test('reflects the stored state', () async {
        expect(await driver.exists('products/photo.png'), isFalse);
        await driver.put(upload, path: 'products');
        expect(await driver.exists('products/photo.png'), isTrue);
      });

      test('maps client failures to BeakStorageException', () async {
        client.failure = Exception('timeout');
        await expectLater(
          driver.exists('products/photo.png'),
          throwsA(isA<BeakStorageException>()),
        );
      });
    });
  });

  group('registerS3Storage', () {
    test('registers a factory the registry resolves for BeakS3Config', () {
      final registry = BeakStorageRegistry();
      registerS3Storage(registry);
      expect(registry.driverIds, contains('s3'));
      expect(registry.resolve(config), isA<S3StorageDriver>());
    });

    test('the factory rejects foreign configs', () {
      expect(
        () => S3StorageDriver.fromConfig(const BeakMemoryStorageConfig()),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
