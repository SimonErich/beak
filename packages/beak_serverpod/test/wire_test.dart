import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

final class _Offline implements Exception {
  const _Offline();
}

final class _Denied implements Exception {
  const _Denied();
}

void main() {
  group('BeakWireRequest', () {
    test('round-trips and keeps only allowlisted, lower-cased headers', () {
      final wire = BeakWireRequest(
        method: 'POST',
        path: '/api/book/query',
        query: 'a=1',
        headers: const {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer forged',
          'Cookie': 'session=x',
          'X-Forwarded-For': '10.0.0.1',
          'X-Beak-Request-Id': 'r1',
        },
        body: '{"table":"book"}',
      );
      final decoded = BeakWireRequest.decode(wire.encode());
      expect(decoded.method, 'POST');
      expect(decoded.path, '/api/book/query');
      expect(decoded.query, 'a=1');
      expect(decoded.body, '{"table":"book"}');
      expect(decoded.headers, {
        'content-type': 'application/json',
        'x-beak-request-id': 'r1',
      });
    });

    test('rejects malformed JSON, missing keys and other versions', () {
      expect(
        () => BeakWireRequest.decode('not json'),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => BeakWireRequest.decode('{"v":1,"method":"GET"}'),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => BeakWireRequest.decode(
          jsonEncode({
            'v': 2,
            'method': 'GET',
            'path': '/',
            'query': '',
            'headers': <String, String>{},
            'body': '',
          }),
        ),
        throwsA(
          isA<BeakValidationException>().having(
            (e) => e.message,
            'message',
            contains('version 2'),
          ),
        ),
      );
    });
  });

  group('BeakWireResponse', () {
    test('round-trips', () {
      const response = BeakWireResponse(
        status: 201,
        headers: {'content-type': 'text/csv'},
        body: 'a,b',
      );
      final decoded = BeakWireResponse.decode(response.encode());
      expect(decoded.status, 201);
      expect(decoded.headers, {'content-type': 'text/csv'});
      expect(decoded.body, 'a,b');
    });

    test('rejects a malformed envelope', () {
      expect(
        () => BeakWireResponse.decode('{"status":"200"}'),
        throwsFormatException,
      );
    });
  });

  group('BeakTunnelHttpClient', () {
    test('carries the request and unwraps the response', () async {
      String? sent;
      final client = BeakTunnelHttpClient((request) async {
        sent = request;
        return const BeakWireResponse(
          status: 200,
          headers: {'content-type': 'application/json'},
          body: '{"ok":true}',
        ).encode();
      });
      final response = await client.post(
        Uri.parse('http://beak.tunnel/api/book/query?x=%20y'),
        headers: {'authorization': 'Bearer t', 'content-type': 'text/plain'},
        body: 'hello',
      );
      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
      expect(response.headers['content-type'], 'application/json');
      final wire = BeakWireRequest.decode(sent!);
      expect(wire.method, 'POST');
      expect(wire.path, '/api/book/query');
      expect(wire.query, 'x=%20y');
      expect(wire.body, 'hello');
      expect(wire.headers.keys, ['content-type']);
    });

    test('maps an HTTP fault to a Beak error body BeakClient types', () async {
      final client = BeakTunnelHttpClient(
        (_) async => throw const _Denied(),
        faults: (error) => switch (error) {
          _Denied() => const BeakTunnelHttpFault(403, 'No beak.admin scope.'),
          _ => null,
        },
      );
      final beak = BeakClient(
        baseUrl: 'http://beak.tunnel',
        httpClient: client,
      );
      await expectLater(
        beak.query('book', const BeakQuerySpec(table: 'book')),
        throwsA(
          isA<BeakAuthorizationException>().having(
            (e) => e.message,
            'message',
            'No beak.admin scope.',
          ),
        ),
      );
      for (final (status, matcher) in [
        (401, isA<BeakAuthenticationException>()),
        (404, isA<BeakNotFoundException>()),
        (409, isA<BeakConflictException>()),
        (413, isA<BeakConfigurationException>()),
      ]) {
        final typed = BeakClient(
          baseUrl: 'http://beak.tunnel',
          httpClient: BeakTunnelHttpClient(
            (_) async => throw const _Denied(),
            faults: (_) => BeakTunnelHttpFault(status, 'status $status'),
          ),
        );
        await expectLater(
          typed.query('book', const BeakQuerySpec(table: 'book')),
          throwsA(matcher),
          reason: '$status',
        );
      }
    });

    test('maps a network fault to http.ClientException', () async {
      final client = BeakTunnelHttpClient(
        (_) async => throw const _Offline(),
        faults: (error) => switch (error) {
          _Offline() => const BeakTunnelNetworkFault('Request timed out.'),
          _ => null,
        },
      );
      await expectLater(
        client.get(Uri.parse('http://beak.tunnel/api/search?q=x')),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            'Request timed out.',
          ),
        ),
      );
    });

    test('lets an unclassified error propagate unchanged', () async {
      const error = _Offline();
      final client = BeakTunnelHttpClient((_) async => throw error);
      await expectLater(
        client.get(Uri.parse('http://beak.tunnel/api/search?q=x')),
        throwsA(same(error)),
      );
    });
  });
}
