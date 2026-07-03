import 'dart:io';
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

BeakUpload _pngUpload({List<int> bytes = const [1, 2, 3]}) => BeakUpload(
  filename: 'a.png',
  mimeType: 'image/png',
  bytes: Uint8List.fromList(bytes),
);

void main() {
  group('BeakLocalDiskStorageDriver', () {
    late Directory tempDir;
    late BeakLocalDiskStorageDriver driver;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('beak_local_disk_test_');
      driver = BeakLocalDiskStorageDriver(
        rootDir: tempDir.path,
        publicBaseUrl: Uri.parse('https://cdn.example.com/files'),
      );
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('identifies as the local driver', () {
      expect(driver.id, 'local');
    });

    test('fromConfig accepts a local-disk config', () {
      expect(
        BeakLocalDiskStorageDriver.fromConfig(
          BeakLocalDiskStorageConfig(
            rootDir: tempDir.path,
            publicBaseUrl: Uri.parse('https://cdn.example.com/files'),
          ),
        ),
        isA<BeakLocalDiskStorageDriver>(),
      );
    });

    test('fromConfig rejects a foreign config', () {
      expect(
        () => BeakLocalDiskStorageDriver.fromConfig(
          const BeakMemoryStorageConfig(),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('put writes the file under nested directories', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads/covers');
      expect(stored.key, 'uploads/covers/a.png');
      expect(
        File('${tempDir.path}/uploads/covers/a.png').readAsBytesSync(),
        const [1, 2, 3],
      );
      expect(stored.sizeInBytes, 3);
      expect(stored.mimeType, 'image/png');
      expect(stored.widthInPixels, isNull);
      expect(stored.variants, isEmpty);
    });

    test('put, get, exists, url and delete round-trip', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads');
      expect(await driver.exists(stored.key), isTrue);
      expect(await driver.get(stored.key), const [1, 2, 3]);
      expect(
        await driver.url(stored.key),
        Uri.parse('https://cdn.example.com/files/uploads/a.png'),
      );
      await driver.delete(stored.key);
      expect(await driver.exists(stored.key), isFalse);
      expect(File('${tempDir.path}/uploads/a.png').existsSync(), isFalse);
    });

    test('put reports the public URL of the stored file', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads');
      expect(
        stored.url,
        Uri.parse('https://cdn.example.com/files/uploads/a.png'),
      );
    });

    test('a base URL without a path keeps only the key path', () async {
      final bare = BeakLocalDiskStorageDriver(
        rootDir: tempDir.path,
        publicBaseUrl: Uri.parse('https://cdn.example.com'),
      );
      expect(
        await bare.url('uploads/a.png'),
        Uri.parse('https://cdn.example.com/uploads/a.png'),
      );
    });

    test('a trailing slash on the root directory is tolerated', () async {
      final slashed = BeakLocalDiskStorageDriver(
        rootDir: '${tempDir.path}/',
        publicBaseUrl: Uri.parse('https://cdn.example.com/files'),
      );
      final stored = await slashed.put(_pngUpload(), path: 'uploads');
      expect(await slashed.get(stored.key), const [1, 2, 3]);
    });

    test('get of a missing key throws', () {
      expect(
        () => driver.get('uploads/missing.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('delete of a missing key throws', () {
      expect(
        () => driver.delete('uploads/missing.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });

    test('url ignores expiry — local URLs do not expire', () async {
      expect(
        await driver.url('uploads/a.png', expiresIn: const Duration(hours: 1)),
        await driver.url('uploads/a.png'),
      );
    });

    test('rejects traversal keys before touching the disk', () {
      expect(
        () => driver.get('../escape.png'),
        throwsA(isA<BeakStorageException>()),
      );
      expect(
        () => driver.put(_pngUpload(), path: '../escape'),
        throwsA(isA<BeakStorageException>()),
      );
    });
  });
}
