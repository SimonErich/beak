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

  group('JSON round-trip', () {
    BeakStoredFile storedFile() => BeakStoredFile(
      key: 'avatars/a.png',
      url: Uri.parse('https://cdn.example/avatars/a.png'),
      sizeInBytes: 1234,
      mimeType: 'image/png',
      widthInPixels: 64,
      heightInPixels: 48,
      variants: {
        'thumb': BeakStoredFileVariant(
          key: 'avatars/a_thumb.png',
          url: Uri.parse('https://cdn.example/avatars/a_thumb.png'),
          widthInPixels: 8,
          heightInPixels: 8,
        ),
      },
    );

    test('serializes every key, writing null for unknown dimensions', () {
      final json = BeakStoredFile(
        key: 'files/doc.pdf',
        url: Uri.parse('memory:///files/doc.pdf'),
        sizeInBytes: 9,
        mimeType: 'application/pdf',
      ).toJson();
      expect(json, {
        'key': 'files/doc.pdf',
        'url': 'memory:///files/doc.pdf',
        'sizeInBytes': 9,
        'mimeType': 'application/pdf',
        'widthInPixels': null,
        'heightInPixels': null,
        'variants': const <String, Object?>{},
      });
    });

    test('decode(encode(file)) is deep-equal', () {
      final file = storedFile();
      expect(BeakStoredFile.fromJson(file.toJson()), file);
      expect(BeakStoredFile.fromJson(file.toJson()).hashCode, file.hashCode);
    });

    test('fromJson rejects a missing key', () {
      final json = storedFile().toJson()..remove('sizeInBytes');
      expect(
        () => BeakStoredFile.fromJson(json),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a non-map variants value', () {
      final json = storedFile().toJson()..['variants'] = 7;
      expect(
        () => BeakStoredFile.fromJson(json),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a variant entry that is not a JSON object', () {
      final json = storedFile().toJson()..['variants'] = {'thumb': 'nope'};
      expect(
        () => BeakStoredFile.fromJson(json),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    BeakStoredFile file({int sizeInBytes = 1, String key = 'k'}) =>
        BeakStoredFile(
          key: key,
          url: Uri.parse('memory:///$key'),
          sizeInBytes: sizeInBytes,
          mimeType: 'application/octet-stream',
        );

    test('equal parts compare and hash equal', () {
      expect(file(), file());
      expect(file().hashCode, file().hashCode);
    });

    test('any differing part breaks equality', () {
      expect(file(), isNot(file(sizeInBytes: 2)));
      expect(file(), isNot(file(key: 'other')));
      expect(
        file(),
        isNot(
          BeakStoredFile(
            key: 'k',
            url: Uri.parse('memory:///k'),
            sizeInBytes: 1,
            mimeType: 'application/octet-stream',
            variants: {
              'v': BeakStoredFileVariant(
                key: 'v',
                url: Uri.parse('memory:///v'),
              ),
            },
          ),
        ),
      );
    });

    test('variants compare by value', () {
      BeakStoredFileVariant variant({int? widthInPixels}) =>
          BeakStoredFileVariant(
            key: 'v',
            url: Uri.parse('memory:///v'),
            widthInPixels: widthInPixels,
          );
      expect(variant(widthInPixels: 3), variant(widthInPixels: 3));
      expect(variant(widthInPixels: 3), isNot(variant(widthInPixels: 4)));
      expect(
        variant(widthInPixels: 3).hashCode,
        variant(widthInPixels: 3).hashCode,
      );
    });
  });

  test('toString names the key and MIME type', () {
    final rendered = BeakStoredFile(
      key: 'files/doc.pdf',
      url: Uri.parse('memory:///files/doc.pdf'),
      sizeInBytes: 9,
      mimeType: 'application/pdf',
    ).toString();
    expect(rendered, contains('files/doc.pdf'));
    expect(rendered, contains('application/pdf'));
  });

  test('variant toString names the key and dimensions', () {
    final rendered = BeakStoredFileVariant(
      key: 'avatars/a_thumb.png',
      url: Uri.parse('memory:///avatars/a_thumb.png'),
      widthInPixels: 8,
      heightInPixels: 8,
    ).toString();
    expect(rendered, contains('avatars/a_thumb.png'));
    expect(rendered, contains('8x8'));
  });
}
