import 'dart:math';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// One valid image per accepted format.
Map<String, Uint8List> validImages() {
  final img.Image picture = img.Image(width: 24, height: 16);
  img.fill(picture, color: img.ColorRgb8(200, 30, 90));
  return {
    'png': img.encodePng(picture),
    'jpg': img.encodeJpg(picture),
    'gif': img.encodeGif(picture),
    'webp': img.encodeWebP(picture),
  };
}

/// Runs [bytes] through the runner and reports anything that is neither a
/// result nor the typed validation error a client can act on.
Future<Object?> untypedFailure(Uint8List bytes) async {
  try {
    await const ImageTransformRunner().run(bytes, const [
      BeakImageTransform.thumbnail(
        size: BeakDimensions.square(8),
        name: 'thumb',
      ),
    ]);
  } on BeakValidationException {
    return null;
  } on Object catch (error) {
    return error;
  }
  return null;
}

void main() {
  group('malformed images are the client\'s mistake, never a crash', () {
    for (final MapEntry(:key, :value) in validImages().entries) {
      test('$key truncated at every length', () async {
        for (var length = 0; length < value.length; length += 1) {
          final Object? failure = await untypedFailure(
            Uint8List.sublistView(value, 0, length),
          );
          expect(failure, isNull, reason: '$key cut at $length: $failure');
        }
      });

      test('$key with random corruption', () async {
        final Random random = Random(7);
        for (var round = 0; round < 300; round += 1) {
          final Uint8List damaged = Uint8List.fromList(value);
          for (var hit = 0; hit < 1 + random.nextInt(4); hit += 1) {
            damaged[random.nextInt(damaged.length)] = random.nextInt(256);
          }
          final Object? failure = await untypedFailure(damaged);
          expect(failure, isNull, reason: '$key round $round: $failure');
        }
      });
    }
  });

  group('an animated GIF', () {
    Uint8List animated({required int frames, required int side}) {
      final img.GifEncoder encoder = img.GifEncoder();
      for (var i = 0; i < frames; i += 1) {
        final img.Image frame = img.Image(width: side, height: side);
        img.fill(frame, color: img.ColorRgb8(i * 5 % 256, 10, 10));
        encoder.addFrame(frame);
      }
      return encoder.finish()!;
    }

    test('is decoded for its first frame only', () async {
      // Every frame of a decoded GIF is a full bitmap in memory, so a small
      // file of many frames would cost frames x the pixel ceiling.
      final Uint8List gif = animated(frames: 60, side: 400);
      final Stopwatch clock = Stopwatch()..start();
      final BeakTransformedImage result = await const ImageTransformRunner()
          .run(gif, const [
            BeakImageTransform.thumbnail(
              size: BeakDimensions.square(8),
              name: 'thumb',
            ),
          ]);
      clock.stop();
      expect(result.mimeType, 'image/gif');
      expect(result.dimensions.widthInPixels, 400);
      final Stopwatch allFrames = Stopwatch()..start();
      img.decodeImage(gif);
      allFrames.stop();
      expect(
        clock.elapsedMicroseconds,
        lessThan(allFrames.elapsedMicroseconds ~/ 3),
        reason: 'the runner must not decode every frame',
      );
    });
  });
}
