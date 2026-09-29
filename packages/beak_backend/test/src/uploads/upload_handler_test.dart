import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/uploads/upload_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';
import '../../support/test_images.dart';

/// Builds a multipart/form-data request with one part.
Request multipartRequest(
  String path, {
  String field = 'file',
  String filename = 'photo.png',
  String mimeType = 'image/png',
  required List<int> bytes,
}) {
  const boundary = 'beak-test-boundary';
  final body = BytesBuilder(copy: false)
    ..add(
      utf8.encode(
        '--$boundary\r\n'
        'content-disposition: form-data; name="$field"; '
        'filename="$filename"\r\n'
        'content-type: $mimeType\r\n\r\n',
      ),
    )
    ..add(bytes)
    ..add(utf8.encode('\r\n--$boundary--\r\n'));
  return Request(
    'POST',
    Uri.parse('http://localhost$path'),
    headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
    body: body.takeBytes(),
  );
}

base class _OwnedMedia extends BeakAllowAllPolicy implements BeakRowPolicy {
  const _OwnedMedia();
  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      model is NoteModel ? NoteModel.authorId.eq(principal?.id) : null;
}

final class _BlockedMedia extends _OwnedMedia implements BeakUploadReadPolicy {
  const _BlockedMedia();
  @override
  bool canViewUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => false;
}

final class _TenantGuard implements BeakAuthGuard {
  const _TenantGuard();
  @override
  Future<BeakPrincipal?> authenticate(Request request) async =>
      BeakPrincipal(id: request.headers['tenant'] ?? 'one');
}

void main() {
  late Handler handler;
  late BeakStorageDriver storage;
  late BeakModelRegistry registry;
  late WormDataSource dataSource;
  late UploadService uploads;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    registry = createApiRegistry();
    storage = BeakMemoryStorageDriver.fromConfig(
      const BeakMemoryStorageConfig(),
    );
    var mintedKeys = 0;
    String mint() => 'minted-${++mintedKeys}';
    dataSource = WormDataSource(registry, adapter: adapter);
    uploads = UploadService(
      registry: registry,
      storage: storage,
      transformRunner: const ImageTransformRunner(),
      generateKeyId: mint,
    );
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: dataSource,
            storage: storage,
            generateId: mint,
          ),
        );
  });

  tearDown(Worm.reset);

  Map<String, Object?> decodeObject(String body) => switch (jsonDecode(body)) {
    final Map<String, Object?> map => map,
    final Object? other => throw StateError('expected JSON object: $other'),
  };

  test(
    'GET upload URL resolves the persisted key and rejects traversal',
    () async {
      final saved = await uploads.handle(
        table: 'notes',
        columnKey: 'avatar',
        upload: BeakUpload(
          filename: 'picture.png',
          mimeType: 'image/png',
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      final response = await handler(
        Request(
          'GET',
          Uri.http('localhost', '/api/notes/avatar/upload', {'key': saved.key}),
        ),
      );
      expect(response.statusCode, 200);
      expect(
        decodeObject(await response.readAsString())['url'],
        saved.url.toString(),
      );
      final invalid = await handler(
        Request(
          'GET',
          Uri.http('localhost', '/api/notes/avatar/upload', {
            'key': 'avatars/../secret.png',
          }),
        ),
      );
      expect(invalid.statusCode, 422);
    },
  );

  test(
    'scoped upload URLs require a visible owning row and honor key-aware policy',
    () async {
      final files = <BeakStoredFile>[];
      for (var i = 0; i < 3; i++) {
        files.add(
          await uploads.handle(
            table: 'notes',
            columnKey: 'avatar',
            upload: BeakUpload(
              filename: 'picture.png',
              mimeType: 'image/png',
              bytes: pngBytes(width: 4, height: 4),
            ),
          ),
        );
      }
      await dataSource.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'first',
          'title': 'First',
          'author_id': 'one',
          'avatar': files[0].key,
        }),
      );
      await dataSource.create(
        'notes',
        BeakRecord.fromRow({
          'id': 'second',
          'title': 'Second',
          'author_id': 'two',
          'avatar': files[1].key,
        }),
      );
      Handler scoped(BeakPolicy policy) => const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addMiddleware(beakAuthMiddleware(guard: const _TenantGuard()))
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: dataSource,
              storage: storage,
              policy: policy,
            ),
          );
      final handler = scoped(const _OwnedMedia());
      Future<Response> read(String key, {String tenant = 'one'}) async =>
          handler(
            Request(
              'GET',
              Uri.http('localhost', '/api/notes/avatar/upload', {'key': key}),
              headers: {'tenant': tenant},
            ),
          );
      expect((await read(files[0].key)).statusCode, 200);
      expect((await read(files[1].key)).statusCode, 404);
      expect((await read(files[1].key, tenant: 'two')).statusCode, 200);
      expect((await read(files[2].key)).statusCode, 404);
      expect(
        (await scoped(const _BlockedMedia())(
          Request(
            'GET',
            Uri.http('localhost', '/api/notes/avatar/upload', {
              'key': files[0].key,
            }),
          ),
        )).statusCode,
        403,
      );
    },
  );

  group('POST /api/{table}/{columnKey}/upload', () {
    test('stores a valid image and returns the typed 201 body', () async {
      final response = await handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          bytes: pngBytes(width: 4, height: 4),
        ),
      );

      expect(response.statusCode, 201);
      final stored = BeakStoredFile.fromJson(
        decodeObject(await response.readAsString()),
      );
      expect(stored.key, 'avatars/minted-1.png');
      expect(stored.mimeType, 'image/png');
      expect(stored.widthInPixels, 4);
      expect(stored.variants.keys, ['thumb']);
      expect(await storage.exists(stored.key), isTrue);
    });

    test('rejects rule violations with a typed 422', () async {
      final response = await handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          bytes: pngBytes(width: 128, height: 128),
        ),
      );
      expect(response.statusCode, 422);
      final body = decodeObject(await response.readAsString());
      expect(body['code'], 'validation');
      expect(body['fieldErrors'], {
        'dimensions': [
          'The image is 128x128 pixels, exceeding the limit of 64x64 pixels.',
        ],
      });
    });

    test('bounds the body read by the column size limit', () async {
      final response = await handler(
        multipartRequest(
          '/api/notes/attachment/upload',
          filename: 'big.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List(2048),
        ),
      );
      expect(response.statusCode, 422);
      final body = decodeObject(await response.readAsString());
      expect(body['fieldErrors'], {
        'size': ['The file exceeds the limit of 1024 bytes.'],
      });
    });

    test('rejects a multipart body without a file field', () async {
      final response = await handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          field: 'not-the-file',
          bytes: pngBytes(width: 2, height: 2),
        ),
      );
      expect(response.statusCode, 422);
    });

    test('rejects a non-multipart body', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes/avatar/upload'),
          body: '{"not": "multipart"}',
        ),
      );
      expect(response.statusCode, 422);
    });

    test('404s an upload to an unknown column', () async {
      final response = await handler(
        multipartRequest(
          '/api/notes/bogus/upload',
          bytes: pngBytes(width: 2, height: 2),
        ),
      );
      expect(response.statusCode, 404);
    });
  });

  group('DELETE /api/{table}/{columnKey}/upload', () {
    test('removes a stored key and 404s a second delete', () async {
      final uploaded = await handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      final stored = BeakStoredFile.fromJson(
        decodeObject(await uploaded.readAsString()),
      );

      Request deleteRequest() => Request(
        'DELETE',
        Uri.parse('http://localhost/api/notes/avatar/upload'),
        body: jsonEncode({'key': stored.key}),
      );

      expect((await handler(deleteRequest())).statusCode, 204);
      expect(await storage.exists(stored.key), isFalse);
      expect((await handler(deleteRequest())).statusCode, 404);
    });

    test('rejects a body without a key string', () async {
      final response = await handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/notes/avatar/upload'),
          body: jsonEncode({'key': 7}),
        ),
      );
      expect(response.statusCode, 422);
    });

    test('consults canDeleteUpload with the storage key, '
        'never canDelete', () async {
      final uploaded = await handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          bytes: pngBytes(width: 4, height: 4),
        ),
      );
      final stored = BeakStoredFile.fromJson(
        decodeObject(await uploaded.readAsString()),
      );

      final policy = _RecordingUploadPolicy();
      final gated = const Pipeline()
          .addMiddleware(beakJsonMiddleware())
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(
            beakApiRouter(
              registry: registry,
              dataSource: dataSource,
              storage: storage,
              policy: policy,
            ),
          );
      final response = await gated(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/notes/avatar/upload'),
          body: jsonEncode({'key': stored.key}),
        ),
      );

      expect(response.statusCode, 204);
      expect(policy.uploadDeleteChecks, [
        (const NoteModel(), NoteColumns.avatar, stored.key),
      ]);
    });
  });

  group('BeakServer wiring', () {
    test(
      'a server with storage serves uploads through the default router',
      () async {
        final registry = createApiRegistry();
        final server = BeakServer(
          config: BeakBackendConfig(
            databaseUrl: Uri.parse('postgres://beak:beak@localhost:25432/beak'),
          ),
          registry: registry,
          dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
          storage: storage,
          onRequest: (entry) {},
        );

        final response = await server.handler(
          multipartRequest(
            '/api/notes/avatar/upload',
            bytes: pngBytes(width: 4, height: 4),
          ),
        );

        expect(response.statusCode, 201);
        final stored = BeakStoredFile.fromJson(
          decodeObject(await response.readAsString()),
        );
        expect(stored.key, startsWith('avatars/'));
        expect(stored.variants.keys, ['thumb']);
      },
    );

    test('a server without storage has no upload routes', () async {
      final registry = createApiRegistry();
      final server = BeakServer(
        config: BeakBackendConfig(
          databaseUrl: Uri.parse('postgres://beak:beak@localhost:25432/beak'),
        ),
        registry: registry,
        dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
        onRequest: (entry) {},
      );

      final response = await server.handler(
        multipartRequest(
          '/api/notes/avatar/upload',
          bytes: pngBytes(width: 2, height: 2),
        ),
      );
      expect(response.statusCode, 404);
    });
  });
}

/// Allows everything but records every upload-delete check; consulting the
/// record-id [BeakPolicy.canDelete] for an upload removal is the regression
/// this fake pins down, so it throws there.
final class _RecordingUploadPolicy implements BeakPolicy {
  _RecordingUploadPolicy();

  /// Every `(model, column, storageKey)` triple `canDeleteUpload` saw.
  final List<(BeakModel, BeakUploadColumn, String)> uploadDeleteChecks = [];

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) => true;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => true;

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) => true;

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) =>
      throw StateError('Upload removal must consult canDeleteUpload.');

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) {
    uploadDeleteChecks.add((model, column, storageKey));
    return true;
  }
}
