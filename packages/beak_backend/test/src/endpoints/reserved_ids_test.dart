import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// A key from an adopted database can hold any character. The client writes it
/// as one percent-encoded path segment, and the routes read it back whole.
void main() {
  late Handler handler;

  setUp(() async {
    Worm.seedRandom(42);
    final registry = createApiRegistry();
    final adapter = await createApiTestDatabase();
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
          ),
        );
  });

  tearDown(Worm.reset);

  const id = 'a/b?c#d%e f';
  final segment = Uri.encodeComponent(id);

  Future<Response> send(String method, String path, [Object? body]) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  test(
    'a record whose key needs encoding is read, updated and deleted',
    () async {
      final created = await send('POST', '/api/labels', {
        'id': id,
        'name': 'x',
      });
      expect(created.statusCode, 201);

      final read = await send('GET', '/api/labels/$segment');
      expect(read.statusCode, 200);
      expect(
        jsonDecode(await read.readAsString()),
        containsPair('values', containsPair('id', id)),
      );

      final patched = await send('PATCH', '/api/labels/$segment', {
        'name': 'y',
      });
      expect(patched.statusCode, 200);

      final deleted = await send('DELETE', '/api/labels/$segment');
      expect(deleted.statusCode, 204);
    },
  );

  test('capabilities reads the id query value once, not twice', () async {
    for (final key in ['100%', '100%25', 'a%2Fb']) {
      final created = await send('POST', '/api/labels', {
        'id': key,
        'name': 'x',
      });
      expect(created.statusCode, 201);
    }

    for (final key in ['100%', '100%25', 'a%2Fb']) {
      final response = await send(
        'GET',
        '/api/labels/capabilities?id=${Uri.encodeQueryComponent(key)}',
      );
      expect(response.statusCode, 200, reason: 'id "$key"');
    }

    final missing = await send(
      'GET',
      '/api/labels/capabilities?id=${Uri.encodeQueryComponent('100%2F')}',
    );
    expect(missing.statusCode, 404);
  });
}
