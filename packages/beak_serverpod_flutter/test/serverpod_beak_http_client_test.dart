import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod_flutter/tunnel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:serverpod_client/serverpod_client.dart';

BeakClient _client(Future<String> Function(String) dispatch) => BeakClient(
  baseUrl: 'http://beak.tunnel',
  httpClient: ServerpodBeakHttpClient(dispatch),
);

Future<void> _query(BeakClient client) =>
    client.query('book', const BeakQuerySpec(table: 'book'));

void main() {
  test('a reply envelope becomes the HTTP response BeakClient reads', () async {
    String? sent;
    final client = _client((request) async {
      sent = request;
      return const BeakWireResponse(
        status: 200,
        headers: {'content-type': 'application/json'},
        body: '{"items":[],"total":0,"page":1,"perPage":25}',
      ).encode();
    });
    final page = await client.query('book', const BeakQuerySpec(table: 'book'));
    expect(page.total, 0);
    final wire = BeakWireRequest.decode(sent!);
    expect(wire.path, '/api/book/query');
    expect(wire.headers, {'content-type': 'application/json'});
  });

  test('sealed Serverpod exceptions map to Beak exceptions', () async {
    final cases = <(Object, Matcher)>[
      (ServerpodClientUnauthorized(), isA<BeakAuthenticationException>()),
      (ServerpodClientForbidden(), isA<BeakAuthorizationException>()),
      (ServerpodClientNotFound(), isA<BeakNotFoundException>()),
      (
        ServerpodClientUnknownHttpException('too big', 413),
        isA<BeakConfigurationException>().having(
          (e) => e.message,
          'message',
          'The request is larger than the server accepts.',
        ),
      ),
      (ServerpodClientInternalServerError(), isA<BeakConfigurationException>()),
      (
        const ServerpodClientUnknownException('odd reply'),
        isA<BeakConfigurationException>().having(
          (e) => e.message,
          'message',
          'odd reply',
        ),
      ),
      (
        const ServerpodClientNetworkException('Request timed out. (x)'),
        isA<http.ClientException>().having(
          (e) => e.message,
          'message',
          'Request timed out. (x)',
        ),
      ),
    ];
    for (final (error, matcher) in cases) {
      await expectLater(
        _query(_client((_) async => throw error)),
        throwsA(matcher),
        reason: '${error.runtimeType}',
      );
    }
  });

  test('an application exception propagates unchanged', () async {
    final error = StateError('not a transport failure');
    await expectLater(
      _query(_client((_) async => throw error)),
      throwsA(same(error)),
    );
  });

  test('serverpodTunnelFault keeps unexpected statuses', () {
    expect(
      serverpodTunnelFault(ServerpodClientUnknownHttpException('x', 429)),
      isA<BeakTunnelHttpFault>().having((f) => f.statusCode, 'status', 429),
    );
    expect(serverpodTunnelFault(Exception('app')), isNull);
  });
}
