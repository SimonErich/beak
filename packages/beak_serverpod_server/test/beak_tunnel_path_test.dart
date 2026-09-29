import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart' show Endpoint, Scope;
import 'package:test/test.dart';

final class _GatedEndpoint extends Endpoint with BeakAdminGate {}

void main() {
  group('beakTunnelUrl', () {
    test('admits the panel routes, re-encoded', () {
      for (final (path, query, expected) in [
        ('/api/book/query', '', 'http://beak.internal/api/book/query'),
        ('/api/book/12', '', 'http://beak.internal/api/book/12'),
        (
          '/api/commits/abc%20def',
          '',
          'http://beak.internal/api/commits/abc%20def',
        ),
        (
          '/api/book/summary',
          'q=moo%20min',
          'http://beak.internal/api/book/summary?q=moo%20min',
        ),
        (
          '/api/book/capabilities',
          'id=3',
          'http://beak.internal/api/book/capabilities?id=3',
        ),
      ]) {
        expect(beakTunnelUrl(path, query)?.toString(), expected, reason: path);
      }
    });

    test('refuses everything outside /api/** and every traversal', () {
      for (final path in [
        '',
        'api/book/query',
        '/',
        '/api',
        '/healthz',
        '/uploads/x.png',
        '/api/auth/login',
        '/api/auth',
        '/api/%61uth/login',
        '/api/book/../auth/login',
        '/api/./book/query',
        '/api/%2e%2e/auth/login',
        '/api/%2E%2E/auth/login',
        '/api//book/query',
        '/api/book/',
        '/api/book%2fquery',
        '/api/book%5cquery',
        '/api/book%00/query',
        '/api/book%0a/query',
        '/api/%zz/query',
        '/API/book/query',
      ]) {
        expect(beakTunnelUrl(path, ''), isNull, reason: path);
      }
    });

    test('refuses oversized paths and queries', () {
      expect(beakTunnelUrl('/api/${'a' * 2100}', ''), isNull);
      expect(beakTunnelUrl('/api/book/query', 'q=${'a' * 9000}'), isNull);
    });
  });

  group('BeakAdminGate', () {
    test('requires a login and the beak.admin scope, not serverpod.admin', () {
      final endpoint = _GatedEndpoint();

      expect(BeakScopes.admin.name, 'beak.admin');
      expect(endpoint.requireLogin, isTrue);
      expect(endpoint.requiredScopes, {BeakScopes.admin});
      expect(endpoint.requiredScopes, isNot(contains(Scope.admin)));
    });
  });
}
