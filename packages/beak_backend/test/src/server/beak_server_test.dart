import 'dart:convert';
import 'dart:io';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/test_models.dart';

void main() {
  late InMemoryAdapter adapter;
  late BeakServer server;
  final entries = <BeakRequestLogEntry>[];

  BeakBackendConfig config({int port = 8080}) => BeakBackendConfig(
    databaseUrl: Uri.parse('postgres://beak:secret@localhost:25432/beak'),
    port: port,
    host: '127.0.0.1',
  );

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createTestDatabase();
    entries.clear();
    server = BeakServer(
      config: config(),
      registry: createTestRegistry(),
      dataSource: WormDataSource(createTestRegistry(), adapter: adapter),
      router: (request) => switch (request.url.path) {
        'ping' => Response.ok('{"pong":true}'),
        'boom' => throw const BeakNotFoundException('nothing here'),
        final String other => throw BeakNotFoundException(
          'No handler for /$other.',
        ),
      },
      onRequest: entries.add,
    );
  });

  tearDown(Worm.reset);

  Map<String, Object?> bodyJson(String body) => switch (jsonDecode(body)) {
    final Map<String, Object?> map => map,
    final Object? other => throw StateError('expected JSON object, got $other'),
  };

  group('handler composition', () {
    test('serves the router through the full middleware stack', () async {
      final response = await server.handler(
        Request('GET', Uri.parse('http://localhost/ping')),
      );

      expect(response.statusCode, 200);
      expect(response.headers['x-request-id'], isNotEmpty);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(response.headers['content-type'], contains('application/json'));
      expect(entries, hasLength(1));
    });

    test('maps thrown Beak failures to JSON error responses', () async {
      final response = await server.handler(
        Request('GET', Uri.parse('http://localhost/boom')),
      );

      expect(response.statusCode, 404);
      final body = bodyJson(await response.readAsString());
      expect(body['code'], 'not_found');
      expect(body['requestId'], isNotEmpty);
    });

    test('answers CORS preflights without touching the router', () async {
      final response = await server.handler(
        Request('OPTIONS', Uri.parse('http://localhost/ping')),
      );
      expect(response.statusCode, 204);
    });

    test('a server without a router 404s everything', () async {
      final bare = BeakServer(
        config: config(),
        registry: createTestRegistry(),
        dataSource: WormDataSource(createTestRegistry(), adapter: adapter),
        onRequest: entries.add,
      );
      final response = await bare.handler(
        Request('GET', Uri.parse('http://localhost/anything')),
      );
      expect(response.statusCode, 404);
      final body = bodyJson(await response.readAsString());
      expect(body['code'], 'not_found');
    });

    test('an auth guard denial surfaces as 403', () async {
      final guarded = BeakServer(
        config: config(),
        registry: createTestRegistry(),
        dataSource: WormDataSource(createTestRegistry(), adapter: adapter),
        authGuard: const _MembersOnlyGuard(),
        onRequest: entries.add,
      );
      final response = await guarded.handler(
        Request('GET', Uri.parse('http://localhost/ping')),
      );
      expect(response.statusCode, 403);
    });
  });

  group('start', () {
    test('binds the configured host and port and serves requests', () async {
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final freePort = probe.port;
      await probe.close();

      final bound = BeakServer(
        config: config(port: freePort),
        registry: createTestRegistry(),
        dataSource: WormDataSource(createTestRegistry(), adapter: adapter),
        router: (request) => Response.ok('{"pong":true}'),
        onRequest: entries.add,
      );
      final httpServer = await bound.start();
      addTearDown(() => httpServer.close(force: true));

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$freePort/ping'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        expect(response.statusCode, 200);
        expect(bodyJson(body), {'pong': true});
      } finally {
        client.close();
      }
    });
  });
}

/// A guard denying every request as an authorization failure.
final class _MembersOnlyGuard implements BeakAuthGuard {
  const _MembersOnlyGuard();

  @override
  Future<BeakPrincipal?> authenticate(Request request) async =>
      throw const BeakAuthorizationException('members only');
}
