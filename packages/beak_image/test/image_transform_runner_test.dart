import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// Encodes a fresh [width]x[height] PNG test image.
Uint8List pngOf(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

/// Whether [bytes] start with the PNG signature.
bool isPng(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

/// Whether [bytes] start with the JPEG signature.
bool isJpg(Uint8List bytes) =>
    bytes.length > 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

/// Whether [bytes] carry the RIFF/WEBP container signature.
bool isWebP(Uint8List bytes) =>
    bytes.length > 12 &&
    String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
    String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';

void main() {
  const runner = ImageTransformRunner();

  group('ImageTransformRunner', () {
    test('an empty pipeline passes the source through untouched', () async {
      final source = pngOf(8, 6);
      final result = await runner.run(source, const []);
      expect(result.bytes, source);
      expect(result.mimeType, 'image/png');
      expect(
        result.dimensions,
        const BeakDimensions(widthInPixels: 8, heightInPixels: 6),
      );
      expect(result.variants, isEmpty);
    });

    group('resize', () {
      test('contain fits within the box preserving aspect ratio', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(widthInPixels: 40, heightInPixels: 40),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 40, heightInPixels: 30),
        );
        expect(result.mimeType, 'image/png');
        expect(isPng(result.bytes), isTrue);
      });

      test('contain with only a width scales to that width', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(widthInPixels: 20),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 20, heightInPixels: 15),
        );
      });

      test('contain with only a height scales to that height', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(heightInPixels: 30),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 40, heightInPixels: 30),
        );
      });

      test('contain upscales smaller sources', () async {
        final result = await runner.run(pngOf(8, 6), const [
          BeakImageTransform.resize(widthInPixels: 16),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 16, heightInPixels: 12),
        );
      });

      test('cover fills the box exactly, cropping the overflow', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(
            widthInPixels: 40,
            heightInPixels: 40,
            fit: BeakImageFit.cover,
          ),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 40, heightInPixels: 40),
        );
      });

      test('cover with a single dimension behaves like contain', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(widthInPixels: 40, fit: BeakImageFit.cover),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 40, heightInPixels: 30),
        );
      });

      test('fill matches the box exactly, distorting the ratio', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.resize(
            widthInPixels: 40,
            heightInPixels: 40,
            fit: BeakImageFit.fill,
          ),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 40, heightInPixels: 40),
        );
      });
    });

    group('format', () {
      test('re-encodes as WebP', () async {
        final result = await runner.run(pngOf(8, 6), const [
          BeakImageTransform.webp(quality: 70),
        ]);
        expect(isWebP(result.bytes), isTrue);
        expect(result.mimeType, 'image/webp');
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 8, heightInPixels: 6),
        );
      });

      test('re-encodes as JPEG', () async {
        final result = await runner.run(pngOf(8, 6), const [
          BeakImageTransform.format(format: BeakImageFormat.jpg, quality: 90),
        ]);
        expect(isJpg(result.bytes), isTrue);
        expect(result.mimeType, 'image/jpeg');
        final decoded = img.decodeImage(result.bytes);
        expect(decoded?.width, 8);
        expect(decoded?.height, 6);
      });

      test('re-encodes as PNG from a JPEG source', () async {
        final jpgSource = img.encodeJpg(img.Image(width: 8, height: 6));
        final result = await runner.run(jpgSource, const [
          BeakImageTransform.format(format: BeakImageFormat.png),
        ]);
        expect(isPng(result.bytes), isTrue);
        expect(result.mimeType, 'image/png');
      });
    });

    group('thumbnail', () {
      test('produces a named cover-cropped variant of exact size', () async {
        final result = await runner.run(pngOf(80, 60), const [
          BeakImageTransform.thumbnail(
            size: BeakDimensions.square(16),
            name: 'thumb',
          ),
        ]);
        expect(
          result.dimensions,
          const BeakDimensions(widthInPixels: 80, heightInPixels: 60),
        );
        expect(result.variants.keys, ['thumb']);
        final variant = result.variants['thumb']!;
        expect(
          variant.dimensions,
          const BeakDimensions(widthInPixels: 16, heightInPixels: 16),
        );
        expect(variant.mimeType, 'image/png');
        expect(isPng(variant.bytes), isTrue);
        expect(variant.variants, isEmpty);
      });

      test(
        'encodes with the format state at its point in the pipeline',
        () async {
          final result = await runner.run(pngOf(80, 60), const [
            BeakImageTransform.resize(widthInPixels: 40),
            BeakImageTransform.webp(),
            BeakImageTransform.thumbnail(size: BeakDimensions.square(16)),
          ]);
          expect(isWebP(result.bytes), isTrue);
          expect(
            result.dimensions,
            const BeakDimensions(widthInPixels: 40, heightInPixels: 30),
          );
          final variant = result.variants['thumbnail']!;
          expect(isWebP(variant.bytes), isTrue);
          expect(variant.mimeType, 'image/webp');
          expect(
            variant.dimensions,
            const BeakDimensions(widthInPixels: 16, heightInPixels: 16),
          );
        },
      );

      test(
        'a thumbnail before a format step keeps the earlier format',
        () async {
          final result = await runner.run(pngOf(80, 60), const [
            BeakImageTransform.thumbnail(size: BeakDimensions.square(16)),
            BeakImageTransform.webp(),
          ]);
          expect(isWebP(result.bytes), isTrue);
          expect(isPng(result.variants['thumbnail']!.bytes), isTrue);
          expect(result.variants['thumbnail']!.mimeType, 'image/png');
        },
      );

      test('duplicate variant names are a configuration error', () async {
        await expectLater(
          runner.run(pngOf(80, 60), const [
            BeakImageTransform.thumbnail(size: BeakDimensions.square(16)),
            BeakImageTransform.thumbnail(size: BeakDimensions.square(32)),
          ]),
          throwsA(isA<BeakConfigurationException>()),
        );
      });
    });

    group('rejection', () {
      test('undecodable bytes are a validation error', () async {
        await expectLater(
          runner.run(Uint8List.fromList([1, 2, 3, 4]), const []),
          throwsA(isA<BeakValidationException>()),
        );
      });

      test(
        'decodable but unsupported formats are a validation error',
        () async {
          final tiff = img.encodeTiff(img.Image(width: 4, height: 4));
          await expectLater(
            runner.run(tiff, const [
              BeakImageTransform.resize(widthInPixels: 2),
            ]),
            throwsA(isA<BeakValidationException>()),
          );
        },
      );
    });
  });
}
