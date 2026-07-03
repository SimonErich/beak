import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

BeakUpload _upload(String filename) => BeakUpload(
  filename: filename,
  mimeType: 'application/octet-stream',
  bytes: Uint8List(0),
);

void main() {
  group('BeakUpload', () {
    test('carries filename, MIME type and bytes', () {
      final upload = BeakUpload(
        filename: 'photo.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );
      expect(upload.filename, 'photo.png');
      expect(upload.mimeType, 'image/png');
      expect(upload.bytes, const [1, 2, 3]);
    });

    test('sizeInBytes is the byte length', () {
      expect(
        BeakUpload(
          filename: 'a.bin',
          mimeType: 'application/octet-stream',
          bytes: Uint8List(42),
        ).sizeInBytes,
        42,
      );
    });

    test('extension is the lower-cased final suffix', () {
      expect(_upload('photo.JPG').extension, 'jpg');
      expect(_upload('archive.tar.gz').extension, 'gz');
    });

    test('extension is null without a real suffix', () {
      expect(_upload('README').extension, isNull);
      expect(_upload('.env').extension, isNull);
      expect(_upload('trailing.').extension, isNull);
    });
  });
}
