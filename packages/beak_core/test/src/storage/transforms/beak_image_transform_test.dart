import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../../support/runtime_values.dart';

/// Exhaustive mapping over the sealed transform family: adding a variant
/// breaks compilation here until it is handled.
String transformKindOf(BeakImageTransform transform) => switch (transform) {
  BeakResizeTransform() => 'resize',
  BeakFormatTransform() => 'format',
  BeakThumbnailTransform() => 'thumbnail',
};

void main() {
  group('BeakImageFit', () {
    test('exposes the documented fits in stable order', () {
      expect(BeakImageFit.values.map((fit) => fit.name), const [
        'cover',
        'contain',
        'fill',
      ]);
    });
  });

  group('BeakImageFormat', () {
    test('exposes the documented formats in stable order', () {
      expect(BeakImageFormat.values.map((format) => format.name), const [
        'jpg',
        'png',
        'webp',
      ]);
    });

    test('every format maps onto its file type', () {
      expect(BeakImageFormat.jpg.fileType, BeakFileType.jpeg);
      expect(BeakImageFormat.png.fileType, BeakFileType.png);
      expect(BeakImageFormat.webp.fileType, BeakFileType.webp);
    });
  });

  group('BeakImageTransform factories', () {
    test('redirect to their variants', () {
      expect(
        const BeakImageTransform.resize(heightInPixels: 900),
        isA<BeakResizeTransform>(),
      );
      expect(
        const BeakImageTransform.format(format: BeakImageFormat.png),
        isA<BeakFormatTransform>(),
      );
      expect(const BeakImageTransform.webp(), isA<BeakFormatTransform>());
      expect(
        const BeakImageTransform.thumbnail(size: BeakDimensions.square(64)),
        isA<BeakThumbnailTransform>(),
      );
    });
  });

  group('BeakResizeTransform', () {
    test('carries the target dimensions and fit', () {
      const resize = BeakResizeTransform(
        widthInPixels: 1600,
        fit: BeakImageFit.cover,
      );
      expect(resize.widthInPixels, 1600);
      expect(resize.heightInPixels, isNull);
      expect(resize.fit, BeakImageFit.cover);
    });

    test('defaults to contain', () {
      expect(
        const BeakResizeTransform(widthInPixels: 100).fit,
        BeakImageFit.contain,
      );
    });

    test('requires at least one target dimension', () {
      expect(
        () => BeakResizeTransform(widthInPixels: runtimeValue(null)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equal transforms compare and hash equal', () {
      final rebuilt = BeakResizeTransform(
        widthInPixels: runtimeValue(1600),
        heightInPixels: 900,
      );
      const resize = BeakResizeTransform(
        widthInPixels: 1600,
        heightInPixels: 900,
      );
      expect(rebuilt, resize);
      expect(rebuilt.hashCode, resize.hashCode);
    });

    test('differs on any field', () {
      const resize = BeakResizeTransform(
        widthInPixels: 1600,
        heightInPixels: 900,
      );
      expect(resize, isNot(const BeakResizeTransform(widthInPixels: 1600)));
      expect(resize, isNot(const BeakResizeTransform(heightInPixels: 900)));
      expect(
        resize,
        isNot(
          const BeakResizeTransform(
            widthInPixels: 1600,
            heightInPixels: 900,
            fit: BeakImageFit.fill,
          ),
        ),
      );
      expect(resize == runtimeValue<Object>('resize'), isFalse);
    });

    test('prints its targets for debugging', () {
      expect(
        const BeakResizeTransform(widthInPixels: 1600).toString(),
        allOf(contains('1600'), contains('contain')),
      );
    });

    test('serializes with every key present', () {
      expect(const BeakResizeTransform(widthInPixels: 1600).toJson(), {
        'type': 'resize',
        'widthInPixels': 1600,
        'heightInPixels': null,
        'fit': 'contain',
      });
    });
  });

  group('BeakFormatTransform', () {
    test('carries format and quality', () {
      const transform = BeakFormatTransform(
        format: BeakImageFormat.png,
        quality: 90,
      );
      expect(transform.format, BeakImageFormat.png);
      expect(transform.quality, 90);
    });

    test('defaults to quality 80 and rejects out-of-range values', () {
      expect(
        const BeakFormatTransform(format: BeakImageFormat.jpg).quality,
        80,
      );
      expect(
        () => BeakFormatTransform(
          format: BeakImageFormat.jpg,
          quality: runtimeValue(101),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BeakFormatTransform(
          format: BeakImageFormat.jpg,
          quality: runtimeValue(-1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('webp shorthand targets the webp format', () {
      const webp = BeakFormatTransform.webp(quality: 70);
      expect(webp.format, BeakImageFormat.webp);
      expect(webp.quality, 70);
      expect(const BeakImageTransform.webp(), const BeakFormatTransform.webp());
    });

    test('equal transforms compare and hash equal', () {
      final rebuilt = BeakFormatTransform(
        format: runtimeValue(BeakImageFormat.webp),
        quality: 70,
      );
      const transform = BeakFormatTransform(
        format: BeakImageFormat.webp,
        quality: 70,
      );
      expect(rebuilt, transform);
      expect(rebuilt.hashCode, transform.hashCode);
    });

    test('differs on any field', () {
      const transform = BeakFormatTransform(format: BeakImageFormat.webp);
      expect(
        transform,
        isNot(const BeakFormatTransform(format: BeakImageFormat.png)),
      );
      expect(
        transform,
        isNot(
          const BeakFormatTransform(format: BeakImageFormat.webp, quality: 1),
        ),
      );
      expect(transform == runtimeValue<Object>('webp'), isFalse);
    });

    test('prints its format for debugging', () {
      expect(
        const BeakFormatTransform(format: BeakImageFormat.webp).toString(),
        allOf(contains('webp'), contains('80')),
      );
    });

    test('serializes with every key present', () {
      expect(const BeakFormatTransform.webp().toJson(), {
        'type': 'format',
        'format': 'webp',
        'quality': 80,
      });
    });
  });

  group('BeakThumbnailTransform', () {
    test('carries its rendition size and name', () {
      const thumbnail = BeakThumbnailTransform(
        size: BeakDimensions.square(64),
        name: 'card',
      );
      expect(thumbnail.size, const BeakDimensions.square(64));
      expect(thumbnail.name, 'card');
    });

    test('defaults to the thumbnail variant name', () {
      expect(
        const BeakThumbnailTransform(size: BeakDimensions.square(64)).name,
        'thumbnail',
      );
    });

    test('rejects an empty variant name', () {
      expect(
        () => BeakThumbnailTransform(
          size: const BeakDimensions.square(64),
          name: runtimeValue(''),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equal transforms compare and hash equal', () {
      final rebuilt = BeakThumbnailTransform(
        size: BeakDimensions.square(runtimeValue(64)),
      );
      const thumbnail = BeakThumbnailTransform(size: BeakDimensions.square(64));
      expect(rebuilt, thumbnail);
      expect(rebuilt.hashCode, thumbnail.hashCode);
    });

    test('differs on any field', () {
      const thumbnail = BeakThumbnailTransform(size: BeakDimensions.square(64));
      expect(
        thumbnail,
        isNot(const BeakThumbnailTransform(size: BeakDimensions.square(32))),
      );
      expect(
        thumbnail,
        isNot(
          const BeakThumbnailTransform(
            size: BeakDimensions.square(64),
            name: 'card',
          ),
        ),
      );
      expect(thumbnail == runtimeValue<Object>('thumbnail'), isFalse);
    });

    test('prints its name and size for debugging', () {
      expect(
        const BeakThumbnailTransform(
          size: BeakDimensions.square(64),
        ).toString(),
        allOf(contains('thumbnail'), contains('64x64')),
      );
    });

    test('serializes with every key present', () {
      expect(
        const BeakThumbnailTransform(size: BeakDimensions.square(64)).toJson(),
        {
          'type': 'thumbnail',
          'size': {'widthInPixels': 64, 'heightInPixels': 64},
          'name': 'thumbnail',
        },
      );
    });
  });

  group('BeakImageTransform.fromJson', () {
    test('round-trips every variant', () {
      const pipeline = <BeakImageTransform>[
        BeakImageTransform.resize(widthInPixels: 1600, fit: BeakImageFit.cover),
        BeakImageTransform.format(format: BeakImageFormat.png, quality: 95),
        BeakImageTransform.webp(quality: 70),
        BeakImageTransform.thumbnail(
          size: BeakDimensions.square(64),
          name: 'card',
        ),
      ];
      for (final transform in pipeline) {
        expect(BeakImageTransform.fromJson(transform.toJson()), transform);
      }
    });

    test('rejects an unknown type tag', () {
      expect(
        () => BeakImageTransform.fromJson(const {'type': 'rotate'}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('requires every key of a variant', () {
      expect(
        () => BeakImageTransform.fromJson(const {
          'type': 'resize',
          'widthInPixels': 1600,
          'heightInPixels': null,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a non-integer resize dimension', () {
      expect(
        () => BeakImageTransform.fromJson(const {
          'type': 'resize',
          'widthInPixels': 'wide',
          'heightInPixels': null,
          'fit': 'contain',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects an unknown fit name', () {
      expect(
        () => BeakImageTransform.fromJson(const {
          'type': 'resize',
          'widthInPixels': 1600,
          'heightInPixels': null,
          'fit': 'stretch',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects an unknown format name', () {
      expect(
        () => BeakImageTransform.fromJson(const {
          'type': 'format',
          'format': 'bmp',
          'quality': 80,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects a thumbnail whose size is not a JSON object', () {
      expect(
        () => BeakImageTransform.fromJson(const {
          'type': 'thumbnail',
          'size': 42,
          'name': 'thumbnail',
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('transform pipelines', () {
    test('preserve declaration order', () {
      const pipeline = <BeakImageTransform>[
        BeakImageTransform.resize(widthInPixels: 1600),
        BeakImageTransform.webp(quality: 85),
        BeakImageTransform.thumbnail(size: BeakDimensions.square(128)),
      ];
      expect(pipeline.map(transformKindOf), const [
        'resize',
        'format',
        'thumbnail',
      ]);
    });
  });
}
