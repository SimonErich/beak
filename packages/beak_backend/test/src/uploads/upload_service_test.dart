import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/src/uploads/upload_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:test/test.dart';

import '../../support/test_images.dart';

/// A model exercising every upload rule: a thumbnailed avatar, a
/// ratio-locked banner, a capped PDF attachment, and a non-file column.
final class _MediaModel extends BeakModel {
  const _MediaModel();

  @override
  String get table => 'media';

  @override
  String get displayColumnKey => 'title';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'title', label: 'Title'),
    BeakImageColumn(
      key: 'avatar',
      label: 'Avatar',
      storagePath: 'avatars',
      maxSizeInBytes: 64 * 1024,
      maxDimensions: BeakDimensions.square(8),
      transforms: [
        BeakThumbnailTransform(size: BeakDimensions.square(2), name: 'thumb'),
        BeakThumbnailTransform(size: BeakDimensions.square(1), name: 'tiny'),
      ],
    ),
    BeakImageColumn(
      key: 'banner',
      label: 'Banner',
      storagePath: 'banners',
      aspectRatio: 1.0,
    ),
    BeakFileColumn(
      key: 'attachment',
      label: 'Attachment',
      storagePath: 'files',
      maxSizeInBytes: 16,
      allowedTypes: [BeakFileType.pdf],
    ),
  ];
}

void main() {
  late BeakStorageDriver storage;
  late UploadService service;
  var mintedKeys = 0;

  setUp(() {
    storage = BeakMemoryStorageDriver.fromConfig(
      const BeakMemoryStorageConfig(),
    );
    mintedKeys = 0;
    service = UploadService(
      registry: BeakModelRegistry()..register(const _MediaModel()),
      storage: storage,
      transformRunner: const ImageTransformRunner(),
      generateKeyId: () => 'minted-${++mintedKeys}',
    );
  });

  BeakUpload pdfUpload({int sizeInBytes = 9}) => BeakUpload(
    filename: 'report.pdf',
    mimeType: 'application/pdf',
    bytes: Uint8List(sizeInBytes),
  );

  BeakUpload pngUpload({int width = 4, int height = 4, String? filename}) =>
      BeakUpload(
        filename: filename ?? 'photo.png',
        mimeType: 'image/png',
        bytes: pngBytes(width: width, height: height),
      );

  Future<Map<String, List<String>>> fieldErrorsOf(
    Future<Object?> Function() call,
  ) async {
    try {
      await call();
    } on BeakValidationException catch (exception) {
      return exception.fieldErrors;
    }
    fail('expected a BeakValidationException');
  }

  test('a failed rendition removes already stored files', () async {
    final failing = _FailSecondWrite(storage);
    final service = UploadService(
      registry: BeakModelRegistry()..register(const _MediaModel()),
      storage: failing,
      transformRunner: const ImageTransformRunner(),
      generateKeyId: () => 'partial',
    );
    await expectLater(
      service.handle(table: 'media', columnKey: 'avatar', upload: pngUpload()),
      throwsA(isA<BeakStorageException>()),
    );
    expect(await storage.exists('avatars/partial.png'), false);
  });

  test(
    'cleanup continues after a custom driver exception and preserves upload failure',
    () async {
      final failing = _FailSecondWrite(
        storage,
        failAt: 3,
        failFirstDelete: true,
      );
      final service = UploadService(
        registry: BeakModelRegistry()..register(const _MediaModel()),
        storage: failing,
        transformRunner: const ImageTransformRunner(),
        generateKeyId: () => 'partial',
      );
      await expectLater(
        service.handle(
          table: 'media',
          columnKey: 'avatar',
          upload: pngUpload(),
        ),
        throwsA(
          isA<BeakStorageException>().having(
            (error) => error.message,
            'original failure',
            'Rendition unavailable',
          ),
        ),
      );
      expect(failing.deleted, [
        'avatars/partial.png',
        'avatars/partial_thumb.png',
      ]);
      expect(await storage.exists('avatars/partial_thumb.png'), isFalse);
    },
  );

  test(
    'stored URLs reject other columns and traversal before driver access',
    () async {
      final saved = await service.handle(
        table: 'media',
        columnKey: 'attachment',
        upload: pdfUpload(),
      );
      expect(await service.url('media', 'attachment', saved.key), saved.url);
      await expectLater(
        service.url('media', 'avatar', saved.key),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        service.url('media', 'attachment', 'files/../secret.pdf'),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );

  group('decompression bombs', () {
    late _CountingRunner runner;
    late UploadService service;

    setUp(() {
      runner = _CountingRunner();
      service = UploadService(
        registry: BeakModelRegistry()..register(const _MediaModel()),
        storage: storage,
        transformRunner: runner,
        generateKeyId: () => 'minted',
      );
    });

    BeakUpload bomb({required int side, String? filename}) => BeakUpload(
      filename: filename ?? 'bomb.png',
      mimeType: 'image/png',
      bytes: pngClaiming(width: side, height: side),
    );

    test('a bitmap over maxDimensions is refused from its header', () async {
      final errors = await fieldErrorsOf(
        () => service.handle(
          table: 'media',
          columnKey: 'avatar',
          upload: bomb(side: 60000),
        ),
      );

      expect(errors['dimensions'], isNotEmpty);
      expect(runner.inspections, 1);
      expect(runner.decodes, 0, reason: 'no pixel may be decoded');
      expect(await storage.exists('avatars/minted.png'), isFalse);
    });

    test('a bitmap the runner will not hold is refused too', () async {
      // The banner column declares no maxDimensions, so only the runner's
      // own ceiling stands between the header and the allocation.
      await expectLater(
        service.handle(
          table: 'media',
          columnKey: 'banner',
          upload: bomb(side: 60000),
        ),
        throwsA(isA<BeakValidationException>()),
      );
      expect(runner.decodes, 1, reason: 'the runner itself refused it');
    });

    test('a valid image is decoded exactly once', () async {
      await service.handle(
        table: 'media',
        columnKey: 'avatar',
        upload: pngUpload(),
      );

      expect(runner.inspections, 1);
      expect(runner.decodes, 1);
    });

    test('a valid image without transforms is decoded exactly once', () async {
      await service.handle(
        table: 'media',
        columnKey: 'banner',
        upload: pngUpload(),
      );

      expect(runner.inspections, 1);
      expect(runner.decodes, 1);
    });
  });

  group('signed URLs', () {
    test(
      'url asks the driver for a signed link with the default lifetime',
      () async {
        final signing = _SigningDriver(storage);
        final service = UploadService(
          registry: BeakModelRegistry()..register(const _MediaModel()),
          storage: signing,
          transformRunner: const ImageTransformRunner(),
        );
        final saved = await service.handle(
          table: 'media',
          columnKey: 'attachment',
          upload: pdfUpload(),
        );

        final url = await service.url('media', 'attachment', saved.key);

        expect(signing.requestedLifetimes, [const Duration(hours: 1)]);
        expect(url.queryParameters['expires'], '3600');
      },
    );

    test('url uses the configured lifetime', () async {
      final signing = _SigningDriver(storage);
      final service = UploadService(
        registry: BeakModelRegistry()..register(const _MediaModel()),
        storage: signing,
        transformRunner: const ImageTransformRunner(),
        signedUrlLifetime: const Duration(minutes: 5),
      );
      final saved = await service.handle(
        table: 'media',
        columnKey: 'attachment',
        upload: pdfUpload(),
      );

      await service.url('media', 'attachment', saved.key);

      expect(signing.requestedLifetimes, [const Duration(minutes: 5)]);
    });

    test('a lifetime that is not positive is rejected at construction', () {
      expect(
        () => UploadService(
          registry: BeakModelRegistry()..register(const _MediaModel()),
          storage: storage,
          transformRunner: const ImageTransformRunner(),
          signedUrlLifetime: Duration.zero,
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('file columns', () {
    test('stores a valid file under a minted key', () async {
      final stored = await service.handle(
        table: 'media',
        columnKey: 'attachment',
        upload: pdfUpload(),
      );
      expect(stored.key, 'files/minted-1.pdf');
      expect(stored.mimeType, 'application/pdf');
      expect(stored.sizeInBytes, 9);
      expect(await storage.exists(stored.key), isTrue);
    });

    test('never trusts the client filename for the key', () async {
      final stored = await service.handle(
        table: 'media',
        columnKey: 'attachment',
        upload: BeakUpload(
          filename: '../../evil.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List(4),
        ),
      );
      expect(stored.key, 'files/minted-1.pdf');
    });

    test('rejects an oversize file with a typed size error', () async {
      final errors = await fieldErrorsOf(
        () => service.handle(
          table: 'media',
          columnKey: 'attachment',
          upload: pdfUpload(sizeInBytes: 17),
        ),
      );
      expect(errors.keys, ['size']);
    });

    test('rejects a disallowed type', () async {
      final errors = await fieldErrorsOf(
        () => service.handle(
          table: 'media',
          columnKey: 'attachment',
          upload: BeakUpload(
            filename: 'photo.png',
            mimeType: 'image/png',
            bytes: Uint8List(8),
          ),
        ),
      );
      expect(errors.keys, ['type']);
    });
  });

  group('image columns', () {
    test('stores a valid image with decoded dimensions', () async {
      final stored = await service.handle(
        table: 'media',
        columnKey: 'avatar',
        upload: pngUpload(width: 4, height: 4),
      );
      expect(stored.key, 'avatars/minted-1.png');
      expect(stored.mimeType, 'image/png');
      expect(stored.widthInPixels, 4);
      expect(stored.heightInPixels, 4);
      expect(await storage.exists(stored.key), isTrue);
    });

    test('runs the transform pipeline and stores named variants', () async {
      final stored = await service.handle(
        table: 'media',
        columnKey: 'avatar',
        upload: pngUpload(width: 4, height: 4),
      );
      final thumb = stored.variants['thumb'];
      expect(thumb, isNotNull);
      expect(thumb?.widthInPixels, 2);
      expect(thumb?.heightInPixels, 2);
      expect(thumb?.key, 'avatars/minted-1_thumb.png');
      expect(await storage.exists(thumb?.key ?? ''), isTrue);
    });

    test('rejects an image over the dimension bounds', () async {
      final errors = await fieldErrorsOf(
        () => service.handle(
          table: 'media',
          columnKey: 'avatar',
          upload: pngUpload(width: 16, height: 16),
        ),
      );
      expect(errors.keys, ['dimensions']);
    });

    test('rejects a mismatched aspect ratio', () async {
      final errors = await fieldErrorsOf(
        () => service.handle(
          table: 'media',
          columnKey: 'banner',
          upload: pngUpload(width: 4, height: 2),
        ),
      );
      expect(errors.keys, ['aspectRatio']);
    });

    test('rejects bytes that are not a decodable image', () {
      expect(
        () => service.handle(
          table: 'media',
          columnKey: 'avatar',
          upload: BeakUpload(
            filename: 'fake.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(utf8.encode('not an image')),
          ),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });

  group('column gating', () {
    test('rejects uploads to non-file columns as invalid requests', () {
      expect(
        () => service.handle(
          table: 'media',
          columnKey: 'title',
          upload: pdfUpload(),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('404s unknown columns and tables', () {
      expect(
        () => service.handle(
          table: 'media',
          columnKey: 'bogus',
          upload: pdfUpload(),
        ),
        throwsA(isA<BeakNotFoundException>()),
      );
      expect(
        () => service.handle(
          table: 'unicorns',
          columnKey: 'avatar',
          upload: pdfUpload(),
        ),
        throwsA(isA<BeakNotFoundException>()),
      );
    });
  });

  group('remove', () {
    test('deletes a stored key', () async {
      final stored = await service.handle(
        table: 'media',
        columnKey: 'attachment',
        upload: pdfUpload(),
      );
      await service.remove('media', 'attachment', stored.key);
      expect(await storage.exists(stored.key), isFalse);
    });

    test('404s a key that is not stored', () {
      expect(
        () => service.remove('media', 'attachment', 'files/ghost.pdf'),
        throwsA(isA<BeakNotFoundException>()),
      );
    });

    test('rejects a key outside the column storage path', () {
      expect(
        () => service.remove('media', 'attachment', 'avatars/minted-1.png'),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });
}

final class _FailSecondWrite implements BeakStorageDriver {
  _FailSecondWrite(
    this.delegate, {
    this.failAt = 2,
    this.failFirstDelete = false,
  });
  final int failAt;
  final bool failFirstDelete;
  final deleted = <String>[];
  final BeakStorageDriver delegate;
  @override
  String get id => delegate.id;
  int writes = 0;
  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) {
    if (++writes == failAt) {
      throw const BeakStorageException('Rendition unavailable');
    }
    return delegate.put(upload, path: path);
  }

  @override
  Future<void> delete(String key) {
    deleted.add(key);
    if (failFirstDelete && deleted.length == 1) {
      throw const FormatException('Custom driver cleanup failure');
    }
    return delegate.delete(key);
  }

  @override
  Future<bool> exists(String key) => delegate.exists(key);
  @override
  Future<Uint8List> get(String key) => delegate.get(key);
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) =>
      delegate.url(key, expiresIn: expiresIn);
}

/// A driver that signs: it records the lifetime it was asked for and puts it
/// in the URL, like a presigning S3 driver does.
final class _SigningDriver implements BeakStorageDriver {
  _SigningDriver(this.delegate);
  final BeakStorageDriver delegate;
  final requestedLifetimes = <Duration>[];
  @override
  String get id => delegate.id;
  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) =>
      delegate.put(upload, path: path);
  @override
  Future<void> delete(String key) => delegate.delete(key);
  @override
  Future<bool> exists(String key) => delegate.exists(key);
  @override
  Future<Uint8List> get(String key) => delegate.get(key);
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    final Uri base = await delegate.url(key);
    if (expiresIn == null) return base;
    requestedLifetimes.add(expiresIn);
    return base.replace(
      queryParameters: {'expires': expiresIn.inSeconds.toString()},
    );
  }
}

/// Wraps the real runner and counts how often the header is read and the
/// pixels are decoded.
final class _CountingRunner implements BeakTransformRunner {
  final BeakTransformRunner _inner = const ImageTransformRunner();
  int inspections = 0;
  int decodes = 0;

  @override
  Future<BeakDimensions> inspect(Uint8List source) {
    inspections += 1;
    return _inner.inspect(source);
  }

  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) {
    decodes += 1;
    return _inner.run(source, pipeline);
  }
}
