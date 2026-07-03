import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_ftp/beak_storage_ftp.dart';
import 'package:test/test.dart';

/// In-memory [FtpTransport] recording every call, with failure knobs.
final class FakeFtpTransport implements FtpTransport {
  final Map<String, Uint8List> files = {};
  final List<String> calls = [];

  /// When set, every method throws this error instead of executing.
  Object? failure;

  void _record(String call) {
    calls.add(call);
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> store(String key, Uint8List bytes) async {
    _record('store $key');
    files[key] = bytes;
  }

  @override
  Future<Uint8List> retrieve(String key) async {
    _record('retrieve $key');
    final Uint8List? bytes = files[key];
    if (bytes == null) {
      throw const FtpProtocolException(550, 'File not found');
    }
    return bytes;
  }

  @override
  Future<void> remove(String key) async {
    _record('remove $key');
    if (files.remove(key) == null) {
      throw const FtpProtocolException(550, 'File not found');
    }
  }

  @override
  Future<bool> exists(String key) async {
    _record('exists $key');
    return files.containsKey(key);
  }
}

void main() {
  final config = BeakFtpConfig(
    host: 'ftp.example.com',
    user: 'beak',
    password: 'secret',
    baseDir: '/srv/uploads',
    publicBaseUrl: Uri.parse('https://static.example.com/uploads'),
  );
  final upload = BeakUpload(
    filename: 'photo.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  late FakeFtpTransport transport;
  late FtpStorageDriver driver;

  setUp(() {
    transport = FakeFtpTransport();
    driver = FtpStorageDriver(config, transport: transport);
  });

  group('FtpStorageDriver', () {
    test('identifies as the "ftp" driver', () {
      expect(driver.id, 'ftp');
    });

    group('put', () {
      test('stores under path/filename and describes the file', () async {
        final stored = await driver.put(upload, path: 'products');
        expect(transport.calls, ['store products/photo.png']);
        expect(transport.files['products/photo.png'], upload.bytes);
        expect(stored.key, 'products/photo.png');
        expect(stored.sizeInBytes, 3);
        expect(stored.mimeType, 'image/png');
        expect(
          stored.url,
          Uri.parse('https://static.example.com/uploads/products/photo.png'),
        );
      });

      test(
        'rejects traversal filenames before touching the transport',
        () async {
          final evil = BeakUpload(
            filename: '../evil.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1]),
          );
          await expectLater(
            driver.put(evil, path: 'products'),
            throwsA(isA<BeakStorageException>()),
          );
          expect(transport.calls, isEmpty);
        },
      );

      test('maps transport failures to BeakStorageException without '
          'claiming a missing file', () async {
        transport.failure = const FtpProtocolException(
          550,
          'Permission denied',
        );
        await expectLater(
          driver.put(upload, path: 'products'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('store'),
                contains('550'),
                isNot(contains('No file is stored')),
              ),
            ),
          ),
        );
      });
    });

    group('get', () {
      test('returns the stored bytes', () async {
        await driver.put(upload, path: 'products');
        expect(await driver.get('products/photo.png'), upload.bytes);
      });

      test('maps a 550 reply to not-found', () async {
        await expectLater(
          driver.get('products/missing.png'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              contains('No file is stored under "products/missing.png"'),
            ),
          ),
        );
      });

      test('rejects malformed keys before touching the transport', () async {
        await expectLater(
          driver.get(r'products\photo.png'),
          throwsA(isA<BeakStorageException>()),
        );
        expect(transport.calls, isEmpty);
      });

      test('maps non-FTP transport failures to BeakStorageException', () async {
        transport.failure = StateError('connection reset');
        await expectLater(
          driver.get('products/photo.png'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              allOf(contains('retrieve'), contains('connection reset')),
            ),
          ),
        );
      });
    });

    group('delete', () {
      test('removes an existing file', () async {
        await driver.put(upload, path: 'products');
        await driver.delete('products/photo.png');
        expect(transport.files, isEmpty);
      });

      test('maps a 550 reply to not-found', () async {
        await expectLater(
          driver.delete('products/missing.png'),
          throwsA(
            isA<BeakStorageException>().having(
              (e) => e.message,
              'message',
              contains('No file is stored under "products/missing.png"'),
            ),
          ),
        );
      });
    });

    group('url', () {
      test('appends the key to the public base URL', () async {
        expect(
          await driver.url('products/photo.png'),
          Uri.parse('https://static.example.com/uploads/products/photo.png'),
        );
      });

      test('ignores expiry — FTP URLs cannot expire', () async {
        expect(
          await driver.url(
            'products/photo.png',
            expiresIn: const Duration(minutes: 5),
          ),
          await driver.url('products/photo.png'),
        );
      });

      test('rejects malformed keys', () async {
        await expectLater(
          driver.url('../secret.png'),
          throwsA(isA<BeakStorageException>()),
        );
      });
    });

    group('exists', () {
      test('reflects the stored state', () async {
        expect(await driver.exists('products/photo.png'), isFalse);
        await driver.put(upload, path: 'products');
        expect(await driver.exists('products/photo.png'), isTrue);
      });

      test('maps transport failures to BeakStorageException', () async {
        transport.failure = Exception('timeout');
        await expectLater(
          driver.exists('products/photo.png'),
          throwsA(isA<BeakStorageException>()),
        );
      });
    });
  });

  group('registerFtpStorage', () {
    test('registers a factory the registry resolves for BeakFtpConfig', () {
      final registry = BeakStorageRegistry();
      registerFtpStorage(registry);
      expect(registry.driverIds, contains('ftp'));
      expect(registry.resolve(config), isA<FtpStorageDriver>());
    });

    test('the factory rejects foreign configs', () {
      expect(
        () => FtpStorageDriver.fromConfig(const BeakMemoryStorageConfig()),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
