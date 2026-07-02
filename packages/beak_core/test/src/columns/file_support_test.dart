import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

/// Exhaustive mapping over the sealed transform family: adding a variant
/// breaks compilation here until it is handled.
String transformKindOf(BeakImageTransform transform) => switch (transform) {
  BeakResizeTransform() => 'resize',
  BeakWebpTransform() => 'webp',
  BeakThumbnailTransform() => 'thumbnail',
};

void main() {
  group('BeakFileType', () {
    test('exposes the documented types in stable order', () {
      expect(BeakFileType.values.map((type) => type.name), const [
        'jpeg',
        'png',
        'webp',
        'gif',
        'svg',
        'pdf',
        'csv',
        'json',
        'zip',
        'mp4',
        'mp3',
      ]);
    });

    test('every type carries a MIME type and lower-case extensions', () {
      for (final type in BeakFileType.values) {
        expect(type.mimeType, contains('/'), reason: '$type');
        expect(type.extensions, isNotEmpty, reason: '$type');
        for (final extension in type.extensions) {
          expect(extension, isNot(startsWith('.')), reason: '$type');
          expect(extension, extension.toLowerCase(), reason: '$type');
        }
      }
    });

    test('jpeg is recognized by both jpg and jpeg extensions', () {
      expect(BeakFileType.jpeg.extensions, containsAll(const ['jpg', 'jpeg']));
    });

    test('isImage matches the image/ MIME family', () {
      expect(BeakFileType.values.where((type) => type.isImage), const [
        BeakFileType.jpeg,
        BeakFileType.png,
        BeakFileType.webp,
        BeakFileType.gif,
        BeakFileType.svg,
      ]);
    });

    test('the default image set is raster-only (no svg)', () {
      expect(BeakFileType.images, const [
        BeakFileType.jpeg,
        BeakFileType.png,
        BeakFileType.webp,
        BeakFileType.gif,
      ]);
    });
  });

  group('BeakDimensions', () {
    test('stores width and height in pixels', () {
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(dimensions.widthInPixels, 800);
      expect(dimensions.heightInPixels, 600);
    });

    test('square uses one size for both sides', () {
      const square = BeakDimensions.square(64);
      expect(square.widthInPixels, 64);
      expect(square.heightInPixels, 64);
    });

    test('equal dimensions compare and hash equal', () {
      final rebuilt = BeakDimensions(
        widthInPixels: runtimeValue(800),
        heightInPixels: 600,
      );
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(rebuilt, dimensions);
      expect(rebuilt.hashCode, dimensions.hashCode);
    });

    test('different dimensions are not equal', () {
      const dimensions = BeakDimensions(
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(
        dimensions,
        isNot(const BeakDimensions(widthInPixels: 600, heightInPixels: 800)),
      );
      expect(dimensions == runtimeValue<Object>('800x600'), isFalse);
    });

    test('rejects non-positive sizes', () {
      expect(
        () =>
            BeakDimensions(widthInPixels: runtimeValue(0), heightInPixels: 600),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BeakDimensions(
          widthInPixels: 800,
          heightInPixels: runtimeValue(-1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('prints its size for debugging', () {
      expect(
        const BeakDimensions(
          widthInPixels: 800,
          heightInPixels: 600,
        ).toString(),
        contains('800x600'),
      );
    });
  });

  group('BeakImageTransform', () {
    test('the sealed factories redirect to their variants', () {
      expect(
        const BeakImageTransform.resize(heightInPixels: 900),
        isA<BeakResizeTransform>(),
      );
      expect(const BeakImageTransform.webp(), isA<BeakWebpTransform>());
      expect(
        const BeakImageTransform.thumbnail(size: BeakDimensions.square(64)),
        isA<BeakThumbnailTransform>(),
      );
    });

    test('resize carries the target dimensions', () {
      const resize = BeakResizeTransform(widthInPixels: 1600);
      expect(resize.widthInPixels, 1600);
      expect(resize.heightInPixels, isNull);
    });

    test('resize requires at least one target dimension', () {
      expect(
        () => BeakResizeTransform(widthInPixels: runtimeValue(null)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('webp defaults to quality 80 and rejects out-of-range values', () {
      const webp = BeakWebpTransform();
      expect(webp.quality, 80);
      expect(
        () => BeakWebpTransform(quality: runtimeValue(101)),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BeakWebpTransform(quality: runtimeValue(-1)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('thumbnail carries its rendition size', () {
      const thumbnail = BeakThumbnailTransform(size: BeakDimensions.square(64));
      expect(thumbnail.size, const BeakDimensions.square(64));
    });

    test('the transform family is sealed', () {
      expect(
        const <BeakImageTransform>[
          BeakImageTransform.resize(widthInPixels: 100),
          BeakImageTransform.webp(quality: 70),
          BeakImageTransform.thumbnail(size: BeakDimensions.square(32)),
        ].map(transformKindOf),
        const ['resize', 'webp', 'thumbnail'],
      );
    });
  });
}
