/// PNG fixtures for the upload suites, generated with the same codec the
/// transform runner uses.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// An encoded PNG of [width] x [height] pixels.
Uint8List pngBytes({required int width, required int height}) =>
    img.encodePng(img.Image(width: width, height: height));
