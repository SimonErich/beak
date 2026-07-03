import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

BeakUpload _pngUpload({List<int> bytes = const [1, 2, 3]}) => BeakUpload(
  filename: 'a.png',
  mimeType: 'image/png',
  bytes: Uint8List.fromList(bytes),
);

void main() {
  group('BeakMemoryStorageDriver', () {
    late BeakMemoryStorageDriver driver;

    setUp(() => driver = BeakMemoryStorageDriver());

    test('identifies as the memory driver', () {
      expect(driver.id, 'memory');
    });

    test('fromConfig accepts a memory config', () {
      expect(
        BeakMemoryStorageDriver.fromConfig(const BeakMemoryStorageConfig()),
        isA<BeakMemoryStorageDriver>(),
      );
    });

    test('fromConfig rejects a foreign config', () {
      expect(
        () => BeakMemoryStorageDriver.fromConfig(
          BeakLocalDiskStorageConfig(
            rootDir: '/tmp/beak',
            publicBaseUrl: Uri.parse('http://localhost:8080/files'),
          ),
        ),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('put stores under path/filename and describes the file', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads/covers');
      expect(stored.key, 'uploads/covers/a.png');
      expect(stored.url, Uri.parse('memory:///uploads/covers/a.png'));
      expect(stored.sizeInBytes, 3);
      expect(stored.mimeType, 'image/png');
      expect(stored.widthInPixels, isNull);
      expect(stored.heightInPixels, isNull);
      expect(stored.variants, isEmpty);
    });

    test('put, get, exists, url and delete round-trip', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads');
      expect(await driver.exists(stored.key), isTrue);
      expect(await driver.get(stored.key), const [1, 2, 3]);
      expect(await driver.url(stored.key), stored.url);
      await driver.delete(stored.key);
      expect(await driver.exists(stored.key), isFalse);
    });

    test('put overwrites an existing key', () async {
      await driver.put(_pngUpload(), path: 'uploads');
      final stored = await driver.put(
        _pngUpload(bytes: const [7, 8]),
        path: 'uploads',
      );
      expect(await driver.get(stored.key), const [7, 8]);
    });

    test('stored bytes are isolated from the upload buffer', () async {
      final upload = _pngUpload();
      final stored = await driver.put(upload, path: 'uploads');
      upload.bytes[0] = 99;
      expect(await driver.get(stored.key), const [1, 2, 3]);
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

    test('url ignores expiry — memory URIs do not expire', () async {
      final stored = await driver.put(_pngUpload(), path: 'uploads');
      expect(
        await driver.url(stored.key, expiresIn: const Duration(minutes: 5)),
        stored.url,
      );
    });

    test('rejects malformed keys before lookup', () {
      expect(
        () => driver.get('../escape.png'),
        throwsA(isA<BeakStorageException>()),
      );
    });
  });
}
