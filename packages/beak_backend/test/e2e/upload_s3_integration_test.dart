@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../src/uploads/upload_handler_test.dart' show multipartRequest;
import '../support/api_models.dart';
import '../support/test_images.dart';

/// The MinIO endpoint under test, matching `docker-compose.yml` /
/// `.env.example` defaults; override via `BEAK_S3_ENDPOINT`.
final Uri endpoint = Uri.parse(
  Platform.environment['BEAK_S3_ENDPOINT'] ?? 'http://localhost:29000',
);

final BeakS3Config s3Config = BeakS3Config(
  endpoint: endpoint,
  bucket: Platform.environment['BEAK_S3_BUCKET'] ?? 'beak-uploads',
  accessKey: Platform.environment['BEAK_S3_ACCESS_KEY'] ?? 'beak',
  secretKey: Platform.environment['BEAK_S3_SECRET_KEY'] ?? 'beaksecret',
  region: Platform.environment['BEAK_S3_REGION'] ?? 'us-east-1',
  usePathStyle: true,
);

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

Future<(int, Uint8List)> httpGet(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return (response.statusCode, builder.takeBytes());
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

  group('uploads against MinIO', () {
    late Handler handler;

    setUp(() async {
      Worm.seedRandom(42);
      final adapter = await createApiTestDatabase();
      final registry = createApiRegistry();
      // `s3` is a plug-in driver: beak_backend no longer depends on
      // beak_storage_s3, so the app registers it itself.
      final storageRegistry = createDefaultStorageRegistry();
      registerS3Storage(storageRegistry);
      handler = const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: WormDataSource(registry, adapter: adapter),
              storage: resolveStorage(s3Config, registry: storageRegistry),
            ),
          );
    });

    tearDown(Worm.reset);

    test(
      'stores an image with its thumbnail, serves both, and deletes them',
      () async {
        if (!guarded()) {
          return;
        }
        final response = await handler(
          multipartRequest(
            '/api/notes/avatar/upload',
            bytes: pngBytes(width: 4, height: 4),
          ),
        );
        expect(response.statusCode, 201);
        final stored = BeakStoredFile.fromJson(switch (jsonDecode(
          await response.readAsString(),
        )) {
          final Map<String, Object?> map => map,
          final Object? other => throw StateError('expected object: $other'),
        });

        final (mainStatus, mainBytes) = await httpGet(stored.url);
        expect(mainStatus, 200, reason: 'main url must serve');
        expect(mainBytes, isNotEmpty);

        final thumb = stored.variants['thumb'];
        expect(thumb, isNotNull, reason: 'thumbnail variant must be stored');
        final (thumbStatus, thumbBytes) = await httpGet(
          thumb?.url ?? Uri.parse('about:blank'),
        );
        expect(thumbStatus, 200, reason: 'thumbnail url must serve');
        expect(thumbBytes, isNotEmpty);

        final deleteResponse = await handler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/notes/avatar/upload'),
            body: jsonEncode({'key': stored.key}),
          ),
        );
        expect(deleteResponse.statusCode, 204);

        final (afterDeleteStatus, _) = await httpGet(stored.url);
        expect(afterDeleteStatus, isNot(200), reason: 'deleted key is gone');
      },
    );
  });
}
