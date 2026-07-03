import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Grants everything to the `admin` role, read-only access to any other
/// authenticated principal, and nothing to anonymous requests.
final class _AdminOnlyWrites implements BeakPolicy {
  const _AdminOnlyWrites();

  bool _isAdmin(BeakPrincipal? principal) =>
      principal?.hasRole('admin') ?? false;

  @override
  bool canView(BeakPrincipal? principal, String table) => principal != null;

  @override
  bool canCreate(BeakPrincipal? principal, String table) => _isAdmin(principal);

  @override
  bool canUpdate(BeakPrincipal? principal, String table, Object id) =>
      _isAdmin(principal);

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) =>
      _isAdmin(principal);
}

void main() {
  late Handler handler;
  late String adminToken;
  late String readerToken;

  setUp(() async {
    Worm.seedRandom(42);
    final adapter = await createApiTestDatabase();
    final registry = createApiRegistry();
    final store = InMemoryTokenSessionStore();
    adminToken = await store.createSession(
      const BeakPrincipal(id: 'admin', roles: {'admin'}),
    );
    readerToken = await store.createSession(const BeakPrincipal(id: 'reader'));
    handler = const Pipeline()
        .addMiddleware(beakJsonMiddleware())
        .addMiddleware(beakErrorMappingMiddleware())
        .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
        .addHandler(
          beakApiRouter(
            registry: registry,
            dataSource: WormDataSource(registry, adapter: adapter),
            policy: const _AdminOnlyWrites(),
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

  group('view protection', () {
    test('anonymous reads are 401', () async {
      final query = await call(
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'notes').toJson(),
      );
      expect(query.statusCode, 401);

      final getOne = await call('GET', '/api/notes/n1');
      expect(getOne.statusCode, 401);
    });

    test('authenticated reads pass', () async {
      final response = await call(
        'POST',
        '/api/notes/query',
        body: const BeakQuerySpec(table: 'notes').toJson(),
        token: readerToken,
      );
      expect(response.statusCode, 200);
    });
  });

  group('write protection', () {
    test('non-admin writes are 403', () async {
      final create = await call(
        'POST',
        '/api/notes',
        body: {'title': 'Nope'},
        token: readerToken,
      );
      expect(create.statusCode, 403);

      final patch = await call(
        'PATCH',
        '/api/notes/n1',
        body: {'title': 'Nope'},
        token: readerToken,
      );
      expect(patch.statusCode, 403);

      final delete = await call('DELETE', '/api/notes/n1', token: readerToken);
      expect(delete.statusCode, 403);

      final attach = await call(
        'POST',
        '/api/notes/n1/relations/labels/attach',
        body: {
          'ids': ['l1'],
        },
        token: readerToken,
      );
      expect(attach.statusCode, 403);
    });

    test('admin writes pass the policy', () async {
      final create = await call(
        'POST',
        '/api/notes',
        body: {'id': 'n1', 'title': 'Allowed'},
        token: adminToken,
      );
      expect(create.statusCode, 201);
    });

    test('the error body distinguishes 401 from 403', () async {
      final anonymous = await call('POST', '/api/notes', body: {'title': 'x'});
      expect(anonymous.statusCode, 401);
      final anonymousBody = switch (jsonDecode(
        await anonymous.readAsString(),
      )) {
        final Map<String, Object?> map => map,
        final Object? other => throw StateError('expected object: $other'),
      };
      expect(anonymousBody['code'], 'authentication');
    });
  });
}
