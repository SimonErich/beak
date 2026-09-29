/// PNG fixtures for the upload suites, generated with the same codec the
/// transform runner uses.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// An encoded PNG of [width] x [height] pixels.
Uint8List pngBytes({required int width, required int height}) =>
    img.encodePng(img.Image(width: width, height: height));

/// A real, tiny PNG whose header claims [width] x [height] pixels: a few dozen
/// bytes that a decoder would inflate into gigabytes.
Uint8List pngClaiming({required int width, required int height}) {
  final Uint8List bytes = Uint8List.fromList(pngBytes(width: 2, height: 2));
  final ByteData view = ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  view.setUint32(29, _crc32(bytes.sublist(12, 29)));
  return bytes;
}

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
