import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  group('BeakStorageKeys.join', () {
    test('joins a path and a filename', () {
      expect(
        BeakStorageKeys.join(path: 'uploads', filename: 'a.png'),
        'uploads/a.png',
      );
    });

    test('trims redundant slashes around the path', () {
      expect(
        BeakStorageKeys.join(path: '/products/covers/', filename: 'a.png'),
        'products/covers/a.png',
      );
    });

    test('an empty path stores at the root', () {
      expect(BeakStorageKeys.join(path: '', filename: 'a.png'), 'a.png');
    });

    test('rejects traversal hidden in the filename', () {
      expect(
        () => BeakStorageKeys.join(path: 'uploads', filename: '../a.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('rejects an empty filename', () {
      expect(
        () => BeakStorageKeys.join(path: 'uploads', filename: ''),
        throwsA(isA<BeakStorageException>()),
      );
    });
  });

  group('BeakStorageKeys.validate', () {
    test('accepts nested keys', () {
      expect(() => BeakStorageKeys.validate('a/b/c.png'), returnsNormally);
    });

    test('rejects empty keys', () {
      expect(
        () => BeakStorageKeys.validate(''),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('rejects absolute keys', () {
      expect(
        () => BeakStorageKeys.validate('/etc/passwd'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('rejects empty segments', () {
      expect(
        () => BeakStorageKeys.validate('a//b.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('rejects dot and dot-dot segments', () {
      expect(
        () => BeakStorageKeys.validate('a/./b.png'),
        throwsA(isA<BeakStorageException>()),
      );
      expect(
        () => BeakStorageKeys.validate('a/../b.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('rejects backslashes', () {
      expect(
        () => BeakStorageKeys.validate(r'a\b.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });
  });

  group('appendToBaseUrl', () {
    test('appends key segments to the base path', () {
      expect(
        BeakStorageKeys.appendToBaseUrl(
          Uri.parse('https://cdn.test/assets/'),
          'products/a.png',
        ).toString(),
        'https://cdn.test/assets/products/a.png',
      );
    });

    test('works from a bare origin', () {
      expect(
        BeakStorageKeys.appendToBaseUrl(
          Uri.parse('http://localhost:29000'),
          'bucket/key.bin',
        ).toString(),
        'http://localhost:29000/bucket/key.bin',
      );
    });
  });
}
