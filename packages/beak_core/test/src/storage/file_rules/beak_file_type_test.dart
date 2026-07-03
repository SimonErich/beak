import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

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
}
