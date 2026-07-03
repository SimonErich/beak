import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  group('BeakStoredFile', () {
    test('carries key, url and metadata', () {
      final file = BeakStoredFile(
        key: 'products/covers/a.png',
        url: Uri.parse('https://cdn.example.com/products/covers/a.png'),
        sizeInBytes: 1024,
        mimeType: 'image/png',
        widthInPixels: 800,
        heightInPixels: 600,
      );
      expect(file.key, 'products/covers/a.png');
      expect(file.url.host, 'cdn.example.com');
      expect(file.sizeInBytes, 1024);
      expect(file.mimeType, 'image/png');
      expect(file.widthInPixels, 800);
      expect(file.heightInPixels, 600);
    });

    test('dimensions and variants are optional', () {
      final file = BeakStoredFile(
        key: 'docs/manual.pdf',
        url: Uri.parse('https://cdn.example.com/docs/manual.pdf'),
        sizeInBytes: 2048,
        mimeType: 'application/pdf',
      );
      expect(file.widthInPixels, isNull);
      expect(file.heightInPixels, isNull);
      expect(file.variants, isEmpty);
    });

    test('exposes named variants', () {
      final thumbnail = BeakStoredFileVariant(
        key: 'products/covers/a_thumbnail.png',
        url: Uri.parse(
          'https://cdn.example.com/products/covers/a_thumbnail.png',
        ),
        widthInPixels: 64,
        heightInPixels: 64,
      );
      final file = BeakStoredFile(
        key: 'products/covers/a.png',
        url: Uri.parse('https://cdn.example.com/products/covers/a.png'),
        sizeInBytes: 1024,
        mimeType: 'image/png',
        variants: {'thumbnail': thumbnail},
      );
      expect(
        file.variants['thumbnail']?.key,
        'products/covers/a_thumbnail.png',
      );
      expect(file.variants['thumbnail']?.widthInPixels, 64);
      expect(file.variants['thumbnail']?.heightInPixels, 64);
    });

    test('variant dimensions are optional', () {
      final variant = BeakStoredFileVariant(
        key: 'a_small.bin',
        url: Uri.parse('memory:///a_small.bin'),
      );
      expect(variant.widthInPixels, isNull);
      expect(variant.heightInPixels, isNull);
    });
  });
}
