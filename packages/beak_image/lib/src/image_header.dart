import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

/// Reads the pixel size a raster image declares in its header, without
/// decoding a pixel.
///
/// Supports the formats [ImageTransformRunner] accepts: PNG, JPEG, GIF and
/// WebP (lossy, lossless and extended). Returns `null` when [bytes] are not
/// one of them, when the header is cut short before the size, or when the
/// size is not positive. Reading it costs a few byte reads whatever the
/// declared bitmap weighs, which is the point: a decoder allocates the whole
/// declared bitmap first.
BeakDimensions? readImageHeaderDimensions(Uint8List bytes) {
  final (int, int)? size = _declaredSize(bytes);
  if (size == null) return null;
  final (int width, int height) = size;
  return width > 0 && height > 0
      ? BeakDimensions(widthInPixels: width, heightInPixels: height)
      : null;
}

(int, int)? _declaredSize(Uint8List bytes) {
  if (_startsWith(bytes, 0, const [0x89, 0x50, 0x4E, 0x47])) return _png(bytes);
  if (_startsWith(bytes, 0, const [0xFF, 0xD8])) return _jpeg(bytes);
  if (_startsWith(bytes, 0, 'GIF8'.codeUnits)) return _gif(bytes);
  if (_startsWith(bytes, 0, 'RIFF'.codeUnits) &&
      _startsWith(bytes, 8, 'WEBP'.codeUnits)) {
    return _webp(bytes);
  }
  return null;
}

bool _startsWith(Uint8List bytes, int offset, List<int> prefix) {
  if (bytes.length < offset + prefix.length) return false;
  for (var i = 0; i < prefix.length; i += 1) {
    if (bytes[offset + i] != prefix[i]) return false;
  }
  return true;
}

/// PNG: the IHDR chunk always comes first, width then height, big endian.
(int, int)? _png(Uint8List bytes) {
  if (bytes.length < 24) return null;
  final ByteData view = ByteData.sublistView(bytes);
  return (view.getUint32(16), view.getUint32(20));
}

/// GIF: the logical screen descriptor follows the six signature bytes.
(int, int)? _gif(Uint8List bytes) {
  if (bytes.length < 10) return null;
  final ByteData view = ByteData.sublistView(bytes);
  return (view.getUint16(6, Endian.little), view.getUint16(8, Endian.little));
}

/// JPEG: walks the marker segments to the first start-of-frame.
(int, int)? _jpeg(Uint8List bytes) {
  final ByteData view = ByteData.sublistView(bytes);
  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF) return null;
    final int marker = bytes[offset + 1];
    if (marker == 0xFF) {
      offset += 1;
    } else if (_isStandaloneMarker(marker)) {
      offset += 2;
    } else if (_isStartOfFrame(marker)) {
      if (offset + 9 > bytes.length) return null;
      return (view.getUint16(offset + 7), view.getUint16(offset + 5));
    } else if (marker == 0xDA) {
      return null;
    } else {
      offset += 2 + view.getUint16(offset + 2);
    }
  }
  return null;
}

/// Markers that carry no length: padding, TEM, SOI and RST0 to RST7.
bool _isStandaloneMarker(int marker) =>
    marker == 0x00 ||
    marker == 0x01 ||
    marker == 0xD8 ||
    (marker >= 0xD0 && marker <= 0xD7);

/// SOF0 to SOF15, minus the three markers in that range that are not frames
/// (DHT, JPG and DAC).
bool _isStartOfFrame(int marker) =>
    marker >= 0xC0 &&
    marker <= 0xCF &&
    marker != 0xC4 &&
    marker != 0xC8 &&
    marker != 0xCC;

/// WebP: the first chunk after the RIFF header says how the size is stored.
(int, int)? _webp(Uint8List bytes) {
  if (bytes.length < 16) return null;
  final ByteData view = ByteData.sublistView(bytes);
  return switch (String.fromCharCodes(bytes, 12, 16)) {
    'VP8 ' when bytes.length >= 30 && _hasVp8StartCode(bytes) => (
      view.getUint16(26, Endian.little) & 0x3FFF,
      view.getUint16(28, Endian.little) & 0x3FFF,
    ),
    'VP8L' when bytes.length >= 25 && bytes[20] == 0x2F => _losslessWebp(
      view.getUint32(21, Endian.little),
    ),
    'VP8X' when bytes.length >= 30 => (
      1 + _uint24(bytes, 24),
      1 + _uint24(bytes, 27),
    ),
    _ => null,
  };
}

bool _hasVp8StartCode(Uint8List bytes) =>
    _startsWith(bytes, 23, const [0x9D, 0x01, 0x2A]);

/// The 14-bit width and height, each stored minus one, of a VP8L stream.
(int, int) _losslessWebp(int bits) =>
    ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);

int _uint24(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
