import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// The CRC-32 a PNG chunk carries over its type and data.
int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final int byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit += 1) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// A real, tiny PNG whose header claims [width] x [height] pixels: a few dozen
/// bytes that a naive decoder would inflate into gigabytes.
Uint8List _pngClaiming(int width, int height) {
  final Uint8List bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 2)),
  );
  final ByteData view = ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  view.setUint32(29, _crc32(bytes.sublist(12, 29)));
  return bytes;
}

/// A JPEG header (SOI, SOF0) claiming [width] x [height] pixels, followed by
/// nothing decodable.
Uint8List _jpegClaiming(int width, int height) {
  final Uint8List bytes = Uint8List(21);
  final ByteData view = ByteData.sublistView(bytes)
    ..setUint16(0, 0xFFD8) // SOI
    ..setUint16(2, 0xFFE0) // APP0
    ..setUint16(4, 4) // segment length: itself plus two bytes
    ..setUint16(8, 0xFFC0) // SOF0
    ..setUint16(10, 11) // segment length
    ..setUint8(12, 8) // sample precision
    ..setUint16(13, height)
    ..setUint16(15, width)
    ..setUint8(17, 1); // one component
  return view.buffer.asUint8List();
}

/// A GIF header claiming a logical screen of [width] x [height] pixels.
Uint8List _gifClaiming(int width, int height) {
  final Uint8List bytes = Uint8List(13)..setRange(0, 6, 'GIF89a'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint16(6, width, Endian.little)
    ..setUint16(8, height, Endian.little);
  return bytes;
}

/// A RIFF/WebP container whose first chunk is [fourCc] with [payload].
Uint8List _webp(String fourCc, List<int> payload) {
  final Uint8List bytes = Uint8List(20 + payload.length)
    ..setRange(0, 4, 'RIFF'.codeUnits)
    ..setRange(8, 12, 'WEBP'.codeUnits)
    ..setRange(12, 16, fourCc.codeUnits)
    ..setRange(20, 20 + payload.length, payload);
  ByteData.sublistView(bytes)
    ..setUint32(4, bytes.length - 8, Endian.little)
    ..setUint32(16, payload.length, Endian.little);
  return bytes;
}

/// A lossy WebP header claiming [width] x [height] pixels.
Uint8List _lossyWebpClaiming(int width, int height) {
  final Uint8List payload = Uint8List(10)
    ..setRange(3, 6, const [0x9D, 0x01, 0x2A]);
  ByteData.sublistView(payload)
    ..setUint16(6, width, Endian.little)
    ..setUint16(8, height, Endian.little);
  return _webp('VP8 ', payload);
}

/// A lossless WebP header claiming [width] x [height] pixels.
Uint8List _losslessWebpClaiming(int width, int height) {
  final Uint8List payload = Uint8List(5)..[0] = 0x2F;
  ByteData.sublistView(
    payload,
  ).setUint32(1, (width - 1) | ((height - 1) << 14), Endian.little);
  return _webp('VP8L', payload);
}

/// An extended WebP header claiming a canvas of [width] x [height] pixels.
Uint8List _extendedWebpClaiming(int width, int height) {
  final Uint8List payload = Uint8List(10);
  final int storedWidth = width - 1;
  final int storedHeight = height - 1;
  payload
    ..[4] = storedWidth & 0xFF
    ..[5] = (storedWidth >> 8) & 0xFF
    ..[6] = (storedWidth >> 16) & 0xFF
    ..[7] = storedHeight & 0xFF
    ..[8] = (storedHeight >> 8) & 0xFF
    ..[9] = (storedHeight >> 16) & 0xFF;
  return _webp('VP8X', payload);
}

BeakDimensions _size(int width, int height) =>
    BeakDimensions(widthInPixels: width, heightInPixels: height);

void main() {
  const runner = ImageTransformRunner();

  group('inspect', () {
    test('reads the size of every supported format from its header', () async {
      final small = img.Image(width: 7, height: 5);
      final sources = <String, Uint8List>{
        'png': img.encodePng(small),
        'jpg': img.encodeJpg(small),
        'gif': img.encodeGif(small),
        'lossless webp': img.encodeWebP(small),
      };
      for (final MapEntry(:key, :value) in sources.entries) {
        expect(await runner.inspect(value), _size(7, 5), reason: key);
      }
    });

    test('reads a lossy and an extended WebP header', () async {
      expect(
        await runner.inspect(_lossyWebpClaiming(320, 200)),
        _size(320, 200),
      );
      expect(
        await runner.inspect(_extendedWebpClaiming(4000, 3000)),
        _size(4000, 3000),
      );
    });

    test('reads the claimed size without decoding a pixel', () async {
      expect(
        await runner.inspect(_pngClaiming(60000, 60000)),
        _size(60000, 60000),
      );
      expect(
        await runner.inspect(_jpegClaiming(60000, 60000)),
        _size(60000, 60000),
      );
      expect(
        await runner.inspect(_gifClaiming(60000, 60000)),
        _size(60000, 60000),
      );
      expect(
        await runner.inspect(_losslessWebpClaiming(16000, 16000)),
        _size(16000, 16000),
      );
    });

    test('rejects bytes that are not a supported image', () async {
      await expectLater(
        runner.inspect(Uint8List.fromList(List.filled(64, 7))),
        throwsA(isA<BeakValidationException>()),
      );
      await expectLater(
        runner.inspect(Uint8List(0)),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('rejects a header cut short before the size', () async {
      final Uint8List png = img.encodePng(img.Image(width: 2, height: 2));
      final Uint8List jpeg = img.encodeJpg(img.Image(width: 2, height: 2));
      final sources = <String, Uint8List>{
        'png': Uint8List.sublistView(png, 0, 20),
        'jpeg': Uint8List.sublistView(jpeg, 0, 6),
        'gif': _gifClaiming(4, 4).sublist(0, 8),
        'webp': _webp('VP8L', const [0x2F]),
      };
      for (final MapEntry(:key, :value) in sources.entries) {
        await expectLater(
          runner.inspect(value),
          throwsA(isA<BeakValidationException>()),
          reason: key,
        );
      }
    });

    test('rejects a header that claims no pixels', () async {
      await expectLater(
        runner.inspect(_pngClaiming(0, 10)),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('rejects a JPEG with no frame header', () async {
      final Uint8List noFrame = Uint8List(6)
        ..setRange(0, 4, const [0xFF, 0xD8, 0xFF, 0xFE]);
      await expectLater(
        runner.inspect(noFrame),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('skips a padding byte and a marker without a length', () async {
      final Uint8List padded = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xFF, // fill byte, then the next marker
        0xFF, 0xD0, // RST0: a marker with no length
        ..._jpegClaiming(30, 20).sublist(8, 21), // SOF0 segment
      ]);

      expect(await runner.inspect(padded), _size(30, 20));
    });

    test('rejects a JPEG whose scan starts before any frame header', () async {
      final Uint8List scanFirst = Uint8List.fromList(const [
        0xFF, 0xD8, // SOI
        0xFF, 0xDA, 0x00, 0x02, // SOS
        0xFF, 0xD9,
      ]);

      await expectLater(
        runner.inspect(scanFirst),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('rejects a WebP whose first chunk is not an image header', () async {
      await expectLater(
        runner.inspect(_webp('ICCP', const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
        throwsA(isA<BeakValidationException>()),
      );
    });
  });

  group('the pixel ceiling', () {
    test('run refuses a claimed bitmap above it without decoding', () async {
      final sources = <String, Uint8List>{
        'png': _pngClaiming(60000, 60000),
        'jpg': _jpegClaiming(60000, 60000),
        'gif': _gifClaiming(60000, 60000),
        'webp': _losslessWebpClaiming(16000, 16000),
      };
      final stopwatch = Stopwatch()..start();
      for (final MapEntry(:key, :value) in sources.entries) {
        await expectLater(
          runner.run(value, const []),
          throwsA(
            isA<BeakValidationException>().having(
              (error) => error.message,
              'message',
              contains('pixels'),
            ),
          ),
          reason: key,
        );
      }
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('run refuses it whatever the pipeline is', () async {
      await expectLater(
        runner.run(_pngClaiming(60000, 60000), const [
          BeakImageTransform.resize(widthInPixels: 100),
        ]),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('the ceiling is configurable', () async {
      const strict = ImageTransformRunner(maxPixelCount: 10);
      final Uint8List fits = img.encodePng(img.Image(width: 3, height: 3));
      final Uint8List tooBig = img.encodePng(img.Image(width: 4, height: 4));

      expect((await strict.run(fits, const [])).dimensions, _size(3, 3));
      await expectLater(
        strict.run(tooBig, const []),
        throwsA(isA<BeakValidationException>()),
      );
    });

    test('an ordinary photo is well below the default ceiling', () {
      expect(
        ImageTransformRunner.defaultMaxPixelCount,
        greaterThanOrEqualTo(24 * 1000 * 1000),
      );
    });
  });
}
