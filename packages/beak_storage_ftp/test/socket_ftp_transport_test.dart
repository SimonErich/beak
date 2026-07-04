import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_ftp/beak_storage_ftp.dart';
import 'package:test/test.dart';

import 'support/mini_ftp_server.dart';

void main() {
  final bytes = Uint8List.fromList(List.generate(300, (i) => i % 256));

  late MiniFtpServer server;
  late BeakFtpConfig config;
  late SocketFtpTransport transport;

  setUp(() async {
    server = MiniFtpServer();
    await server.start();
    config = BeakFtpConfig(
      host: '127.0.0.1',
      port: server.port,
      user: 'beak',
      password: 'secret',
      baseDir: '/srv/uploads/',
      publicBaseUrl: Uri.parse('https://static.example.com/uploads'),
    );
    transport = SocketFtpTransport(config);
  });

  tearDown(() => server.stop());

  group('SocketFtpTransport', () {
    test(
      'store creates the directory chain under baseDir and uploads',
      () async {
        await transport.store('products/2026/photo.png', bytes);
        expect(server.files, {'/srv/uploads/products/2026/photo.png': bytes});
        expect(
          server.directories,
          containsAll(const [
            '/srv',
            '/srv/uploads',
            '/srv/uploads/products',
            '/srv/uploads/products/2026',
          ]),
        );
      },
    );

    test('a relative baseDir keeps MKD and STOR paths relative and '
        'consistent', () async {
      final relative = SocketFtpTransport(
        BeakFtpConfig(
          host: '127.0.0.1',
          port: server.port,
          user: 'beak',
          password: 'secret',
          baseDir: 'uploads',
          publicBaseUrl: Uri.parse('https://static.example.com/uploads'),
        ),
      );

      await relative.store('products/photo.png', bytes);

      final mkdPaths = [
        for (final command in server.commands)
          if (command.startsWith('MKD ')) command.substring(4),
      ];
      final storPath = server.commands
          .firstWhere((command) => command.startsWith('STOR '))
          .substring(5);

      // The created directories are rooted exactly where STOR writes —
      // relative to the login directory, not the filesystem root.
      expect(mkdPaths, ['uploads', 'uploads/products']);
      expect(storPath, 'uploads/products/photo.png');
    });

    test('store overwrites an existing file', () async {
      await transport.store('a.bin', Uint8List.fromList([1]));
      await transport.store('a.bin', bytes);
      expect(server.files['/srv/uploads/a.bin'], bytes);
    });

    test('a refused upload surfaces the server reply code', () async {
      server.refuseStores = true;
      await expectLater(
        transport.store('a.bin', bytes),
        throwsA(
          isA<FtpProtocolException>().having(
            (e) => e.replyCode,
            'replyCode',
            451,
          ),
        ),
      );
    });

    test('retrieve returns the stored bytes', () async {
      server.files['/srv/uploads/a.bin'] = bytes;
      expect(await transport.retrieve('a.bin'), bytes);
    });

    test('retrieve of a missing file throws a 550', () async {
      await expectLater(
        transport.retrieve('missing.bin'),
        throwsA(
          isA<FtpProtocolException>().having(
            (e) => e.replyCode,
            'replyCode',
            550,
          ),
        ),
      );
    });

    test('remove deletes the stored file', () async {
      server.files['/srv/uploads/a.bin'] = bytes;
      await transport.remove('a.bin');
      expect(server.files, isEmpty);
    });

    test('remove of a missing file throws a 550', () async {
      await expectLater(
        transport.remove('missing.bin'),
        throwsA(
          isA<FtpProtocolException>().having(
            (e) => e.replyCode,
            'replyCode',
            550,
          ),
        ),
      );
    });

    test('exists reflects the stored state', () async {
      expect(await transport.exists('a.bin'), isFalse);
      server.files['/srv/uploads/a.bin'] = bytes;
      expect(await transport.exists('a.bin'), isTrue);
    });

    test('a wrong password surfaces the 530 reply', () async {
      final rejected = SocketFtpTransport(
        BeakFtpConfig(
          host: '127.0.0.1',
          port: server.port,
          user: 'beak',
          password: 'wrong',
          baseDir: '/srv/uploads',
          publicBaseUrl: Uri.parse('https://static.example.com/uploads'),
        ),
      );
      await expectLater(
        rejected.exists('a.bin'),
        throwsA(
          isA<FtpProtocolException>().having(
            (e) => e.replyCode,
            'replyCode',
            530,
          ),
        ),
      );
    });
  });

  group('FtpStorageDriver over a real socket', () {
    test('put, get, exists, url and delete round-trip', () async {
      final driver = FtpStorageDriver(config);
      final upload = BeakUpload(
        filename: 'photo.png',
        mimeType: 'image/png',
        bytes: bytes,
      );
      final stored = await driver.put(upload, path: 'products');
      expect(stored.key, 'products/photo.png');
      expect(
        stored.url,
        Uri.parse('https://static.example.com/uploads/products/photo.png'),
      );
      expect(await driver.get('products/photo.png'), bytes);
      expect(await driver.exists('products/photo.png'), isTrue);
      await driver.delete('products/photo.png');
      expect(await driver.exists('products/photo.png'), isFalse);
      await expectLater(
        driver.get('products/photo.png'),
        throwsA(
          isA<BeakStorageException>().having(
            (e) => e.message,
            'message',
            contains('No file is stored under "products/photo.png"'),
          ),
        ),
      );
    });
  });
}
