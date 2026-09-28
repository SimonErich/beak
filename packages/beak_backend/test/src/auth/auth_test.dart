import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

void main() {
  const secret = 'unit-test-secret';
  final fixedNow = DateTime.utc(2026, 7, 3, 12);
  late DateTime currentTime;
  late InMemoryTokenSessionStore store;
  late Handler handler;

  final adminAccount = BeakUserAccount(
    username: 'admin',
    passwordHash: hashBeakPassword('cat-tax', secret: secret),
    principal: const BeakPrincipal(id: 'admin', roles: {'admin'}),
  );

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    final registry = createApiRegistry();
    currentTime = fixedNow;
    var mintedTokens = 0;
    store = InMemoryTokenSessionStore(
      sessionTtl: const Duration(hours: 1),
      now: () => currentTime,
      generateToken: () => 'token-${++mintedTokens}',
    );
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
            auth: BeakAuthSessions(
              store: store,
              users: [adminAccount],
              secret: secret,
            ),
          ),
        );
  });

  tearDown(Worm.reset);

  Future<Response> call(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Map<String, Object?> decodeObject(String body) => switch (jsonDecode(body)) {
    final Map<String, Object?> map => map,
    final Object? other => throw StateError('expected JSON object: $other'),
  };

  Future<String> login() async {
    final response = await call(
      'POST',
      '/api/auth/login',
      body: {'username': 'admin', 'password': 'cat-tax'},
    );
    expect(response.statusCode, 200);
    return switch (decodeObject(await response.readAsString())['token']) {
      final String token => token,
      final Object? other => throw StateError('expected a token: $other'),
    };
  }

  group('login', () {
    test('valid credentials issue an opaque session token', () async {
      final token = await login();
      expect(token, 'token-1');
    });

    test('the login response carries the typed principal', () async {
      final response = await call(
        'POST',
        '/api/auth/login',
        body: {'username': 'admin', 'password': 'cat-tax'},
      );
      final body = decodeObject(await response.readAsString());
      expect(body['principal'], {
        'id': 'admin',
        'roles': ['admin'],
      });
    });

    test('a wrong password is a 401', () async {
      final response = await call(
        'POST',
        '/api/auth/login',
        body: {'username': 'admin', 'password': 'dog-tax'},
      );
      expect(response.statusCode, 401);
      expect(
        decodeObject(await response.readAsString())['code'],
        'authentication',
      );
    });

    test('an unknown user is the same 401 as a wrong password', () async {
      final response = await call(
        'POST',
        '/api/auth/login',
        body: {'username': 'ghost', 'password': 'cat-tax'},
      );
      expect(response.statusCode, 401);
    });

    test('a malformed body is a 422', () async {
      final response = await call(
        'POST',
        '/api/auth/login',
        body: {'username': 'admin'},
      );
      expect(response.statusCode, 422);
    });
  });

  group('me', () {
    test('returns the principal for a valid Bearer token', () async {
      final token = await login();
      final response = await call('GET', '/api/auth/me', token: token);
      expect(response.statusCode, 200);
      expect(decodeObject(await response.readAsString()), {
        'id': 'admin',
        'roles': ['admin'],
      });
    });

    test('401s without a token', () async {
      final response = await call('GET', '/api/auth/me');
      expect(response.statusCode, 401);
    });

    test('401s an unknown token', () async {
      final response = await call('GET', '/api/auth/me', token: 'forged');
      expect(response.statusCode, 401);
    });

    test('401s an expired session', () async {
      final token = await login();
      currentTime = fixedNow.add(const Duration(hours: 2));
      final response = await call('GET', '/api/auth/me', token: token);
      expect(response.statusCode, 401);
    });
  });

  group('logout', () {
    test('invalidates the session token', () async {
      final token = await login();
      final logout = await call('POST', '/api/auth/logout', token: token);
      expect(logout.statusCode, 204);

      final afterLogout = await call('GET', '/api/auth/me', token: token);
      expect(afterLogout.statusCode, 401);
    });

    test('401s without a token', () async {
      final response = await call('POST', '/api/auth/logout');
      expect(response.statusCode, 401);
    });
  });

  group('password hashing', () {
    test('hashes are deterministic per secret and never the plaintext', () {
      final hash = hashBeakPassword('cat-tax', secret: secret);
      expect(hash, hashBeakPassword('cat-tax', secret: secret));
      expect(hash, isNot(contains('cat-tax')));
      expect(hash, isNot(hashBeakPassword('cat-tax', secret: 'other')));
      expect(hash, isNot(hashBeakPassword('dog-tax', secret: secret)));
    });

    test('accounts store only the hash', () {
      expect(adminAccount.passwordHash, isNot(contains('cat-tax')));
    });
  });

  group('token store', () {
    test('sessions are opaque server-side entries', () async {
      final token = await store.createSession(const BeakPrincipal(id: 'u1'));
      expect(await store.sessionFor(token), const BeakPrincipal(id: 'u1'));
      await store.revoke(token);
      expect(await store.sessionFor(token), isNull);
    });
  });
}
