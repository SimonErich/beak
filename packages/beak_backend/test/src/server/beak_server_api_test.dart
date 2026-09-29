import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Resolves every request to one fixed principal.
final class _FixedGuard implements BeakAuthGuard {
  const _FixedGuard(this.principal);

  final BeakPrincipal principal;

  @override
  Future<BeakPrincipal?> authenticate(Request request) async => principal;
}

void main() {
  late InMemoryAdapter adapter;
  late BeakModelRegistry registry;
  final frozen = DateTime.utc(2030, 1, 2, 3, 4, 5);
  final config = BeakBackendConfig(
    databaseUrl: Uri.parse('postgres://beak:beak@localhost:25432/beak'),
  );

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createApiTestDatabase();
    await const BeakCommitReceiptsMigration().up(adapter);
    registry = createApiRegistry();
  });
  tearDown(Worm.reset);

  BeakServer server({
    DateTime Function()? now,
    String Function()? generateId,
    List<Middleware> middleware = const [],
    Handler? routes,
    String corsOrigin = '*',
    BeakAuthSessions? authSessions,
    BeakAuthGuard? authGuard,
    BeakSavePlanPreparer? preparePlan,
    List<BeakModel> graphOnly = const [],
    BeakDataSource? dataSource,
    BeakUnexpectedErrorListener? onUnexpectedError,
  }) => BeakServer(
    config: config,
    registry: registry,
    dataSource: dataSource ?? WormDataSource(registry, adapter: adapter),
    now: now,
    generateId: generateId,
    middleware: middleware,
    routes: routes,
    corsOrigin: corsOrigin,
    authSessions: authSessions,
    authGuard: authGuard,
    preparePlan: preparePlan,
    graphOnly: graphOnly,
    onRequest: (entry) {},
    onUnexpectedError: onUnexpectedError,
  );

  Future<Response> send(
    BeakServer server,
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async => server.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      switch (jsonDecode(await response.readAsString())) {
        final Map<String, Object?> map => map,
        final Object? other => throw StateError('expected an object: $other'),
      };

  BeakSavePlan createNote(String saveId) => BeakSavePlan(
    saveId: saveId,
    root: const BeakRecordRef.draft('notes', 'draft'),
    operations: [
      BeakSaveOperation(
        id: 'create',
        kind: BeakSaveOperationKind.create,
        target: const BeakRecordRef.draft('notes', 'draft'),
        values: BeakRecord.fromRow({'title': 'Committed'}),
      ),
    ],
  );

  group('clock and id seams', () {
    test('reach the per-record write routes', () async {
      final response = await send(
        server(now: () => frozen, generateId: () => 'minted'),
        'POST',
        '/api/notes',
        body: {'title': 'Direct'},
      );

      expect(response.statusCode, 201);
      final created = BeakRecord.fromJson(await bodyOf(response));
      expect(NoteColumns.id.readFrom(created), 'minted');
      expect(NoteColumns.createdAt.readFrom(created), frozen);
    });

    test('reach the graph commits', () async {
      final response = await send(
        server(now: () => frozen, generateId: () => 'minted'),
        'POST',
        '/api/commits',
        body: createNote('seams').toJson(),
      );

      expect(response.statusCode, 200);
      final result = BeakSaveResult.fromJson(await bodyOf(response));
      expect(NoteColumns.id.readFrom(result.rootRecord!), 'minted');
      expect(NoteColumns.createdAt.readFrom(result.rootRecord!), frozen);
    });
  });

  group('corsOrigin', () {
    test('names the one origin a browser may call from', () async {
      final response = await send(
        server(corsOrigin: 'https://admin.example'),
        'OPTIONS',
        '/api/notes/query',
      );

      expect(response.statusCode, 204);
      expect(
        response.headers['access-control-allow-origin'],
        'https://admin.example',
      );
    });
  });

  group('middleware', () {
    test('runs in order, inside the auth and error mapping', () async {
      final seen = <String>[];
      Middleware recording(String name) =>
          (inner) => (request) {
            seen.add('$name:${beakPrincipal(request)?.id}');
            if (request.url.path == 'api/blocked') {
              throw const BeakAuthorizationException('blocked');
            }
            return inner(request);
          };

      final response = await send(
        server(
          authGuard: const _FixedGuard(BeakPrincipal(id: 'ada')),
          middleware: [recording('outer'), recording('inner')],
        ),
        'GET',
        '/api/blocked',
      );

      expect(seen, ['outer:ada'], reason: 'the first one listed runs first');
      expect(response.statusCode, 403);
      expect((await bodyOf(response))['code'], 'authorization');
    });
  });

  group('routes', () {
    final routes = Router()
      ..get('/api/ping', (Request request) => Response.ok('{"pong":true}'))
      ..get(
        '/api/notes/stats',
        (Request request) => Response.ok('{"notes":"custom"}'),
      );

    test('are served beside the generated API', () async {
      final configured = server(routes: routes.call);

      final ping = await send(configured, 'GET', '/api/ping');
      final query = await send(
        configured,
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'notes').toJson(),
      );

      expect(ping.statusCode, 200);
      expect(await bodyOf(ping), {'pong': true});
      expect(query.statusCode, 200, reason: 'unmatched paths fall through');
    });

    test('win over a generated route on the same path', () async {
      // `GET /api/notes/<id>` would otherwise read "stats" as a record id.
      final response = await send(
        server(routes: routes.call),
        'GET',
        '/api/notes/stats',
      );

      expect(response.statusCode, 200);
      expect(await bodyOf(response), {'notes': 'custom'});
    });

    test('sit behind the same auth guard as the API', () async {
      final guarded = server(
        routes: routes.call,
        authGuard: const _FixedGuard(BeakPrincipal(id: 'ada')),
        middleware: [
          (inner) => (request) {
            expect(beakPrincipal(request)?.id, 'ada');
            return inner(request);
          },
        ],
      );

      expect((await send(guarded, 'GET', '/api/ping')).statusCode, 200);
    });
  });

  group('authSessions', () {
    const secret = 'server-test-secret';
    // --8<-- [start:authSessionsFixture]
    BeakAuthSessions sessions() => BeakAuthSessions(
      store: InMemoryTokenSessionStore(),
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'admin',
          passwordHash: hashBeakPassword('cat-tax', secret: secret),
          principal: const BeakPrincipal(id: 'admin', roles: {'admin'}),
        ),
      ],
    );
    // --8<-- [end:authSessionsFixture]

    Future<String> login(BeakServer server) async {
      final response = await send(
        server,
        'POST',
        '/api/auth/login',
        body: {'username': 'admin', 'password': 'cat-tax'},
      );
      expect(response.statusCode, 200);
      return switch ((await bodyOf(response))['token']) {
        final String token => token,
        final Object? other => throw StateError('expected a token: $other'),
      };
    }

    test('validate the tokens they issue without an explicit guard', () async {
      // Issuing tokens that nothing checks would leave /me forever 401 and
      // every policy looking at an anonymous caller.
      final configured = server(authSessions: sessions());
      final token = await login(configured);

      final me = await send(
        configured,
        'GET',
        '/api/auth/me',
        headers: {'authorization': 'Bearer $token'},
      );

      expect(me.statusCode, 200);
      expect(await bodyOf(me), containsPair('id', 'admin'));
    });

    test('reject a forged token rather than serving it anonymously', () async {
      final response = await send(
        server(authSessions: sessions()),
        'GET',
        '/api/auth/me',
        headers: const {'authorization': 'Bearer forged'},
      );

      expect(response.statusCode, 401);
    });

    test('never guard the health probes, whatever the header says', () async {
      final configured = server(authSessions: sessions());

      for (final probe in ['/healthz', '/readyz']) {
        final response = await send(
          configured,
          'GET',
          probe,
          headers: const {'authorization': 'Bearer forged'},
        );
        expect(response.statusCode, 200, reason: probe);
      }
    });

    test('guard everything else, including a lookalike of a probe', () async {
      final configured = server(authSessions: sessions());

      for (final path in ['/api/healthz', '/api/notes/capabilities']) {
        final response = await send(
          configured,
          'GET',
          path,
          headers: const {'authorization': 'Bearer forged'},
        );
        expect(response.statusCode, 401, reason: path);
      }
    });

    test('leave an explicit guard in charge', () async {
      final configured = server(
        authSessions: sessions(),
        authGuard: const _FixedGuard(BeakPrincipal(id: 'gateway')),
      );

      final me = await send(configured, 'GET', '/api/auth/me');

      expect(me.statusCode, 200);
      expect(await bodyOf(me), containsPair('id', 'gateway'));
    });
  });

  group('graphOnly', () {
    test('closes the per-record routes of the named models', () async {
      final configured = server(
        preparePlan: (plan, source, principal) async => plan,
        graphOnly: const [NoteModel()],
      );

      final direct = await send(
        configured,
        'POST',
        '/api/notes',
        body: {'title': 'Direct'},
      );
      final committed = await send(
        configured,
        'POST',
        '/api/commits',
        body: createNote('graph').toJson(),
      );

      expect(direct.statusCode, 422);
      expect(committed.statusCode, 200);
    });
  });

  group('onUnexpectedError', () {
    test('hears the failure the readiness probe hides', () async {
      final reported = <Object>[];
      final configured = server(
        dataSource: WormDataSource(registry, adapter: InMemoryAdapter()),
        onUnexpectedError: (error, stackTrace) => reported.add(error),
      );

      final response = await send(configured, 'GET', '/readyz');

      expect(response.statusCode, 503);
      expect(reported, hasLength(1));
      expect(
        await response.readAsString(),
        isNot(contains('${reported.single}')),
      );
    });
  });
}
