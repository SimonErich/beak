import 'dart:convert';
import 'dart:typed_data';

import 'package:beak_backend/beak_backend.dart';
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
