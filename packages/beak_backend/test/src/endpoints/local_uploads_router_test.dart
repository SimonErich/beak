import 'dart:convert';
import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/endpoints/local_uploads_router.dart';
import 'package:beak_core/io.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

/// Sends [rawPath] exactly as written (no client-side normalization) and
/// returns the status line code and the head/body text of the answer.
Future<({int status, Map<String, String> headers, String body})> rawGet(
  HttpServer server,
  String rawPath,
) async {
  final Socket socket = await Socket.connect('127.0.0.1', server.port);
  socket.write(
    'GET $rawPath HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
  );
  await socket.flush();
  final String raw = await utf8.decoder.bind(socket).join();
  socket.destroy();
  final int split = raw.indexOf('\r\n\r\n');
  final List<String> head = raw.substring(0, split).split('\r\n');
  return (
    status: int.parse(head.first.split(' ')[1]),
    headers: {
      for (final String line in head.skip(1))
        line.substring(0, line.indexOf(':')).toLowerCase(): line
            .substring(line.indexOf(':') + 1)
            .trim(),
    },
    body: raw.substring(split + 4),
  );
}

void main() {
  late Directory sandbox;
  late HttpServer server;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('beak_local_uploads');
    await Directory('${sandbox.path}/root/photos').create(recursive: true);
    await File('${sandbox.path}/root/photos/a.png').writeAsString('png-bytes');
    await File('${sandbox.path}/root/photos/page.html').writeAsString('<b>x');
    await File('${sandbox.path}/secret.txt').writeAsString('top-secret');
    await File(
      '${sandbox.path}/root-sibling.txt',
    ).writeAsString('sibling-file-content');
    final BeakLocalDiskStorageDriver driver = BeakLocalDiskStorageDriver(
      rootDir: '${sandbox.path}/root',
      publicBaseUrl: Uri.parse('http://localhost/uploads'),
    );
    server = await shelf_io.serve(
      const Pipeline()
          .addMiddleware(beakErrorMappingMiddleware())
          .addHandler(beakLocalUploadsRouter(driver).call),
      '127.0.0.1',
      0,
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await sandbox.delete(recursive: true);
  });

  test('serves a stored file with its type and length', () async {
    final answer = await rawGet(server, '/uploads/photos/a.png');
    expect(answer.status, 200);
    expect(answer.body, 'png-bytes');
    expect(answer.headers['content-type'], 'image/png');
    expect(answer.headers['content-length'], '9');
  });

  test('serves a key that needs percent-encoding in its URL', () async {
    await File('${sandbox.path}/root/photos/a b é.png').writeAsString('spaced');
    final answer = await rawGet(server, '/uploads/photos/a%20b%20%C3%A9.png');
    expect(answer.status, 200);
    expect(answer.body, 'spaced');
  });

  test('a missing file is a 404', () async {
    expect((await rawGet(server, '/uploads/photos/none.png')).status, 404);
  });

  for (final String hostile in [
    '/uploads/../secret.txt',
    '/uploads/photos/../../secret.txt',
    '/uploads/%2e%2e/secret.txt',
    '/uploads/%2E%2E/%2E%2E/secret.txt',
    '/uploads/photos/%2e%2e/%2e%2e/secret.txt',
    '/uploads/..%2fsecret.txt',
    '/uploads/photos/..%2f..%2fsecret.txt',
    '/uploads/%2e%2e%2fsecret.txt',
    '/uploads/..%5csecret.txt',
    '/uploads/photos%2f..%2f..%2fsecret.txt',
    '/uploads/../root-sibling.txt',
    '/uploads/..%2froot-sibling.txt',
    '/uploads/%2e%2e%2froot-sibling.txt',
    '/uploads//etc/passwd',
    '/uploads/%2fetc%2fpasswd',
    '/uploads/photos/a.png%00.txt',
  ]) {
    test('does not serve anything outside the root for $hostile', () async {
      final answer = await rawGet(server, hostile);
      expect(answer.body, isNot(contains('top-secret')));
      expect(answer.body, isNot(contains('sibling-file-content')));
      expect(answer.body, isNot(contains('root:')));
      expect(answer.status, isNot(200));
    });
  }

  test('a symlink inside the root does not lead out of it', () async {
    await Link(
      '${sandbox.path}/root/photos/leak.txt',
    ).create('${sandbox.path}/secret.txt');
    final answer = await rawGet(server, '/uploads/photos/leak.txt');
    expect(answer.body, isNot(contains('top-secret')));
    expect(answer.status, 404);
  });

  test(
    'an upload can never run as a page in the origin that serves it',
    () async {
      final answer = await rawGet(server, '/uploads/photos/page.html');
      expect(answer.headers['x-content-type-options'], 'nosniff');
      expect(answer.headers['content-security-policy'], contains('sandbox'));
      expect(answer.headers['content-disposition'], startsWith('attachment'));
    },
  );

  test('every served file is marked nosniff', () async {
    final answer = await rawGet(server, '/uploads/photos/a.png');
    expect(answer.headers['x-content-type-options'], 'nosniff');
    expect(answer.headers['content-disposition'], isNull);
  });
}
