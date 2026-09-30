import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('logout supersedes a pending HTTP login response', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final store = BeakSessionStore(
      BeakClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) {
          requested.complete();
          return response.future;
        }),
      ),
    );
    final login = store.login(email: 'person@example.com', password: 'secret');
    await requested.future;
    await store.logout();
    response.complete(
      http.Response(
        jsonEncode({
          'token': 'late-token',
          'principal': {
            'id': 'user',
            'roles': ['admin'],
          },
        }),
        200,
      ),
    );
    expect((await login).isOk, false);
    expect(store.token, null);
    expect(store.state.value, isA<BeakAuthGuest>());
  });

  test(
    'default adapter signs in through HTTP and clears before remote logout',
    () async {
      final revocation = Completer<http.Response>();
      late BeakSessionStore store;
      final requests = <http.Request>[];
      final client = BeakClient(
        baseUrl: 'http://example.test',
        tokenProvider: () => store.token,
        httpClient: MockClient((request) async {
          requests.add(request);
          return request.url.path.endsWith('logout')
              ? revocation.future
              : http.Response(
                  jsonEncode({
                    'token': 'bearer',
                    'principal': {
                      'id': 'user',
                      'roles': ['admin'],
                    },
                  }),
                  200,
                );
        }),
      );
      store = BeakSessionStore(client);
      expect(
        await store.signIn(username: 'person@example.com', password: 'secret'),
        true,
      );
      expect(store.state.value, isA<BeakAuthAuthenticated>());
      expect(store.session.value?.hasRole('admin'), true);
      expect(jsonDecode(requests.first.body), {
        'username': 'person@example.com',
        'password': 'secret',
      });
      await store.refresh();
      final logout = store.logout();
      expect(store.isSignedIn, false);
      expect(store.token, null);
      revocation.complete(http.Response('{}', 200));
      expect((await logout).isOk, true);
      expect(requests.last.headers['authorization'], 'Bearer bearer');
      expect(store.state.value, isA<BeakAuthGuest>());
    },
  );

  test(
    'bad credentials and broken transport stay typed, with no false success',
    () async {
      final rejected = BeakSessionStore(
        BeakClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response('{"error":"denied"}', 401),
          ),
        ),
      );
      expect(
        await rejected.signIn(
          username: 'person@example.com',
          password: 'wrong',
        ),
        false,
      );
      expect(rejected.isSignedIn, false);
      final broken = BeakSessionStore(
        BeakClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) => throw http.ClientException('private network detail'),
          ),
        ),
      );
      expect(
        (await broken.login(
          email: 'person@example.com',
          password: 'secret',
        )).isOk,
        false,
      );
      expect(broken.token, null);
    },
  );
}
