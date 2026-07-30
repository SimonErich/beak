import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:minio/minio.dart';
// Shown selectively: the model barrel also declares an `Object` that would
// shadow `dart:core`'s in this file.
// `Error` is minio's S3 error model and would shadow dart:core's here.
import 'package:minio/models.dart' as minio show Error;
import 'package:minio/models.dart' show StatObjectResult;
import 'package:test/test.dart';

/// One recorded `putObject` call.
final class RecordedPut {
  /// Records an upload of [bytes] to [bucket]/[key], declared as [size] bytes
  /// with [metadata] headers.
  RecordedPut({
    required this.bucket,
    required this.key,
    required this.bytes,
    required this.size,
    required this.metadata,
  });

  /// The target bucket.
  final String bucket;

  /// The object key within the bucket.
  final String key;

  /// The bytes drained from the upload stream.
  final Uint8List bytes;

  /// The declared content length.
  final int? size;

  /// The request headers, as `package:minio` names them.
  final Map<String, String>? metadata;
}

/// One recorded `presignedGetObject` call.
final class RecordedPresign {
  /// Records a presign request for [bucket]/[key] valid [expiresInSeconds].
  RecordedPresign({
    required this.bucket,
    required this.key,
    required this.expiresInSeconds,
  });

  /// The target bucket.
  final String bucket;

  /// The object key within the bucket.
  final String key;

  /// The requested validity, in seconds.
  final int? expiresInSeconds;
}

/// The error `package:minio` raises for an HTTP [statusCode], shaped the way
/// its own response validation shapes one.
///
/// `validate` parses S3's XML body into minio's `Error` and passes
/// `error.message` as the exception message, keeping the documented code on
/// the error itself. Getting that split wrong is how a check for a missing
/// object can look right and never fire, so the fixture reproduces it:
/// message is the sentence, code is `NoSuchKey`.
///
/// The fixture carries no `MinioResponse`, so these tests exercise the code
/// branch of `isMissingObject`. Building a response needs `package:minio`'s
/// internals, and the status branch is covered where a real one exists:
/// `test/e2e/` raises a genuine 404 from MinIO.
MinioS3Error s3Error(int statusCode, String message) => MinioS3Error(
  message,
  minio.Error(
    statusCode == 404 ? 'NoSuchKey' : 'InternalError',
    null,
    message,
    null,
  ),
);

/// A [Minio] double serving objects from memory.
///
/// A missing key answers with the 404 [MinioS3Error] a real endpoint raises;
/// [failure], when set, replaces every answer, which is how a test reproduces
/// a non-404 S3 error or a transport error that never reached S3.
final class FakeMinio extends Minio {
  /// Creates a double addressing a nominal endpoint, which the base
  /// constructor validates but never contacts.
  FakeMinio() : super(endPoint: 'localhost', accessKey: 'ak', secretKey: 'sk');

  /// The stored objects, keyed by object key.
  final Map<String, Uint8List> objects = {};

  /// Every upload, in order.
  final List<RecordedPut> puts = [];

  /// The keys passed to `removeObject`, in order.
  final List<String> removedKeys = [];

  /// Every presign request, in order.
  final List<RecordedPresign> presigns = [];

  /// Thrown by every operation instead of its normal answer.
  Object? failure;

  void _failIfArmed() {
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
  }

  Uint8List _require(String key) {
    final Uint8List? bytes = objects[key];
    if (bytes == null) {
      throw s3Error(404, 'The specified key does not exist.');
    }
    return bytes;
  }

  @override
  Future<String> putObject(
    String bucket,
    String object,
    Stream<Uint8List> data, {
    int? size,
    int? chunkSize,
    Map<String, String>? metadata,
    void Function(int)? onProgress,
  }) async {
    _failIfArmed();
    final BytesBuilder builder = BytesBuilder(copy: false);
    await data.forEach(builder.add);
    final Uint8List bytes = builder.takeBytes();
    objects[object] = bytes;
    puts.add(
      RecordedPut(
        bucket: bucket,
        key: object,
        bytes: bytes,
        size: size,
        metadata: metadata,
      ),
    );
    return 'etag-${puts.length}';
  }

  @override
  Future<MinioByteStream> getObject(String bucket, String object) async {
    _failIfArmed();
    final Uint8List bytes = _require(object);
    // Split so the adapter has to join chunks the way a real body arrives.
    final int half = bytes.length ~/ 2;
    return MinioByteStream.fromStream(
      stream: Stream<List<int>>.fromIterable([
        bytes.sublist(0, half),
        bytes.sublist(half),
      ]),
      contentLength: bytes.length,
    );
  }

  @override
  Future<void> removeObject(String bucket, String object) async {
    _failIfArmed();
    objects.remove(object);
    removedKeys.add(object);
  }

  @override
  Future<StatObjectResult> statObject(
    String bucket,
    String object, {
    bool retrieveAcls = true,
  }) async {
    _failIfArmed();
    return StatObjectResult(size: _require(object).length);
  }

  @override
  Future<String> presignedGetObject(
    String bucket,
    String object, {
    int? expires,
    Map<String, String>? respHeaders,
    DateTime? requestDate,
  }) async {
    _failIfArmed();
    presigns.add(
      RecordedPresign(bucket: bucket, key: object, expiresInSeconds: expires),
    );
    return 'https://signed.example.com/$bucket/$object?expires=$expires';
  }
}

void main() {
  final config = BeakS3Config(
    endpoint: Uri.parse('http://localhost:29000'),
    bucket: 'beak-uploads',
    accessKey: 'ak',
    secretKey: 'sk',
    region: 'us-east-1',
    usePathStyle: true,
  );
  final Uint8List bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  late FakeMinio minio;
  late MinioS3ObjectClient client;

  setUp(() {
    minio = FakeMinio();
    client = MinioS3ObjectClient(config, minio: minio);
  });

  group('MinioS3ObjectClient', () {
    group('putObject', () {
      test('streams the bytes with their length and content type', () async {
        await client.putObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          bytes: bytes,
          contentType: 'image/png',
        );
        final RecordedPut put = minio.puts.single;
        expect(put.bucket, 'beak-uploads');
        expect(put.key, 'products/photo.png');
        expect(put.bytes, bytes);
        expect(put.size, 5);
        expect(put.metadata, {'content-type': 'image/png'});
      });

      test('lets upload failures through, rather than reporting success', () {
        // A guard against a future try/catch here: an upload that failed and
        // returned normally would leave a record pointing at a key the bucket
        // has not got, and nothing downstream would notice until a read.
        minio.failure = s3Error(403, 'Access Denied');
        return expectLater(
          client.putObject(
            bucket: 'beak-uploads',
            key: 'products/photo.png',
            bytes: bytes,
            contentType: 'image/png',
          ),
          throwsA(
            isA<MinioS3Error>().having(
              (error) => error.message,
              'message',
              'Access Denied',
            ),
          ),
        );
      });
    });

    group('getObject', () {
      test('joins the response chunks into one buffer', () async {
        minio.objects['products/photo.png'] = bytes;
        expect(
          await client.getObject(
            bucket: 'beak-uploads',
            key: 'products/photo.png',
          ),
          bytes,
        );
      });

      test('returns null when S3 answers 404', () async {
        expect(
          await client.getObject(
            bucket: 'beak-uploads',
            key: 'products/missing.png',
          ),
          isNull,
        );
      });

      test('rethrows an S3 error that is not a missing object', () async {
        minio.failure = s3Error(500, 'Internal Error');
        await expectLater(
          client.getObject(bucket: 'beak-uploads', key: 'products/photo.png'),
          throwsA(
            isA<MinioS3Error>().having(
              (e) => e.message,
              'message',
              'Internal Error',
            ),
          ),
        );
      });

      test('rethrows an S3 error raised before any response', () async {
        minio.failure = MinioS3Error('connection reset');
        await expectLater(
          client.getObject(bucket: 'beak-uploads', key: 'products/photo.png'),
          throwsA(isA<MinioS3Error>()),
        );
      });

      test('lets a non-S3 transport failure through', () async {
        minio.failure = StateError('socket closed');
        await expectLater(
          client.getObject(bucket: 'beak-uploads', key: 'products/photo.png'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('removeObject', () {
      test('deletes the key', () async {
        minio.objects['products/photo.png'] = bytes;
        await client.removeObject(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
        );
        expect(minio.removedKeys, ['products/photo.png']);
        expect(minio.objects, isEmpty);
      });
    });

    group('objectExists', () {
      test('is true when the object can be stat-ed', () async {
        minio.objects['products/photo.png'] = bytes;
        expect(
          await client.objectExists(
            bucket: 'beak-uploads',
            key: 'products/photo.png',
          ),
          isTrue,
        );
      });

      test('is false when S3 answers 404', () async {
        expect(
          await client.objectExists(
            bucket: 'beak-uploads',
            key: 'products/missing.png',
          ),
          isFalse,
        );
      });

      test('rethrows an S3 error that is not a missing object', () async {
        minio.failure = s3Error(403, 'Access Denied');
        await expectLater(
          client.objectExists(
            bucket: 'beak-uploads',
            key: 'products/photo.png',
          ),
          throwsA(isA<MinioS3Error>()),
        );
      });

      test('lets a non-S3 transport failure through', () async {
        minio.failure = StateError('socket closed');
        await expectLater(
          client.objectExists(
            bucket: 'beak-uploads',
            key: 'products/photo.png',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('presignedGetUrl', () {
      test('passes the expiry in seconds and parses the signed URL', () async {
        final Uri url = await client.presignedGetUrl(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          expiresIn: const Duration(minutes: 5),
        );
        final RecordedPresign presign = minio.presigns.single;
        expect(presign.bucket, 'beak-uploads');
        expect(presign.key, 'products/photo.png');
        expect(presign.expiresInSeconds, 300);
        expect(url.host, 'signed.example.com');
        expect(url.path, '/beak-uploads/products/photo.png');
      });
    });

    group('the wire client built from the config', () {
      test('signs a presigned URL against the configured endpoint', () async {
        // Presigning is computed locally, so this exercises the real
        // `package:minio` client the constructor builds by default.
        final Uri url = await MinioS3ObjectClient(config).presignedGetUrl(
          bucket: 'beak-uploads',
          key: 'products/photo.png',
          expiresIn: const Duration(minutes: 5),
        );
        expect(url.host, 'localhost');
        expect(url.port, 29000);
        expect(url.scheme, 'http');
        expect(url.path, '/beak-uploads/products/photo.png');
        expect(url.queryParameters['X-Amz-Expires'], '300');
        expect(url.queryParameters['X-Amz-Signature'], isNotEmpty);
      });

      test('uses TLS and the implied port for an https endpoint', () async {
        final Uri url =
            await MinioS3ObjectClient(
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
        expect(
          url.queryParameters['X-Amz-Credential'],
          contains('eu-central-1'),
        );
      });
    });
  });
}
