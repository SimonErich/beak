/// A `lib/server.dart` imports one library. Everything it names to add
/// middleware or routes must come through it, since a project depending on
/// `beak` alone cannot import `shelf` itself.
library;

import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// Stamps every response, the way a project's own middleware would.
Middleware _stamped() =>
    (Handler inner) =>
        (Request request) async => (await inner(
          request,
        )).change(headers: {'x-served-by': 'lib/server'});

Response _stats(Request request) => Response.ok(jsonEncode({'notes': 0}));

BeakServer _beakServer(BeakServerDefaults defaults) => defaults.build(
  middleware: [_stamped()],
  routes: (Router()..get('/api/stats', _stats)).call,
);

void main() {
  late InMemoryAdapter adapter;

  setUp(() async => adapter = await createApiTestDatabase());
  tearDown(Worm.reset);

  test('the barrel carries the Shelf types a customizer names', () async {
    final server = BeakServeHost(
      registry: createApiRegistry(),
      configure: _beakServer,
      environment: const {'DATABASE_URL': 'sqlite::memory:'},
    ).buildServer(adapter: adapter);

    final response = await const Pipeline().addHandler(server.handler)(
      Request('GET', Uri.parse('http://localhost/api/stats')),
    );

    expect(response.statusCode, 200);
    expect(response.headers['x-served-by'], 'lib/server');
    expect(jsonDecode(await response.readAsString()), {'notes': 0});
  });
}
