import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// A minimal in-test runner proving the interface is implementable without
/// an image library: it echoes the source bytes and reports fixed metadata.
final class _EchoRunner implements BeakTransformRunner {
  const _EchoRunner();

  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) async => BeakTransformedImage(
    bytes: source,
    mimeType: 'image/webp',
    dimensions: const BeakDimensions(widthInPixels: 1600, heightInPixels: 900),
    variants: {
      'thumbnail': BeakTransformedImage(
        bytes: source,
        mimeType: 'image/webp',
        dimensions: const BeakDimensions.square(64),
      ),
    },
  );
}

void main() {
  group('BeakTransformedImage', () {
    test('carries bytes, MIME type and dimensions', () {
      final image = BeakTransformedImage(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'image/png',
        dimensions: const BeakDimensions(widthInPixels: 10, heightInPixels: 20),
      );
      expect(image.bytes, const [1, 2, 3]);
      expect(image.mimeType, 'image/png');
      expect(image.dimensions.widthInPixels, 10);
      expect(image.variants, isEmpty);
    });
  });

  group('BeakTransformRunner', () {
    test('an implementation runs a pipeline and reports variants', () async {
      const runner = _EchoRunner();
      final source = Uint8List.fromList(const [9, 8, 7]);
      final result = await runner.run(source, const [
        BeakImageTransform.resize(widthInPixels: 1600),
        BeakImageTransform.webp(),
        BeakImageTransform.thumbnail(size: BeakDimensions.square(64)),
      ]);
      expect(result.bytes, source);
      expect(result.mimeType, 'image/webp');
      expect(
        result.dimensions,
        const BeakDimensions(widthInPixels: 1600, heightInPixels: 900),
      );
      expect(result.variants.keys, const ['thumbnail']);
      expect(
        result.variants['thumbnail']?.dimensions,
        const BeakDimensions.square(64),
      );
      expect(result.variants['thumbnail']?.variants, isEmpty);
    });
  });
}
