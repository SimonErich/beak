import 'dart:convert';

import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:serverpod/serverpod.dart' show LogLevel;
import 'package:test/test.dart';
import 'package:worm/worm.dart' hide LogLevel;

import 'support/book_models.dart';
import 'support/fake_serverpod.dart';

const _staff = 'bookshop.staff';

/// Staff read and write books; authors have no rule, so they are closed.
BeakPolicies _policy() => BeakPolicies(
  rules: [
    BeakModelRules(
      const BookModel(),
      read: const BeakAccess.role(_staff),
      write: const BeakAccess.role(_staff),
    ),
  ],
);

/// Records the principal every request is decided for.
final class _Recording extends BeakAllowAllPolicy {
  BeakPrincipal? seen;

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) {
    seen = principal;
    return true;
  }
}

final class _Exploding extends BeakAllowAllPolicy {
  @override
  bool canView(BeakPrincipal? principal, BeakModel model) =>
      throw StateError('policy blew up');
}

String _request(
  String method,
  String path, {
  Object? body,
  String query = '',
  Map<String, String> headers = const {},
}) => BeakWireRequest(
  method: method,
  path: path,
  query: query,
  headers: {'content-type': 'application/json', ...headers},
  body: body == null ? '' : jsonEncode(body),
).encode();

BeakWireResponse _decode(String envelope) => BeakWireResponse.decode(envelope);

Map<String, Object?> _json(BeakWireResponse response) =>
    switch (jsonDecode(response.body)) {
      final Map<String, Object?> map => map,
      _ => fail('Expected a JSON object, got ${response.body}'),
    };

BeakSavePlan _plan(String saveId) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('book', 'b'),
  operations: [
    BeakSaveOperation(
      id: 'b',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('book', 'b'),
      values: BeakRecord.fromRow({'title': 'Moominland', 'priceInCents': 1200}),
    ),
  ],
);

void main() {
  late InMemoryAdapter adapter;
  late BeakServerpodEngine engine;
  late FakeSession staff;

  setUp(() async {
    Worm.seedRandom(42);
    adapter = await createBookshopDatabase();
    engine = BeakServerpodEngine(
      registry: createBookshopRegistry(),
      policy: _policy(),
      adapter: adapter,
    );
    staff = FakeSession(authenticated: signedIn({'beak.admin', _staff}));
  });

  Future<BeakWireResponse> call(
    String method,
    String path, {
    Object? body,
    String query = '',
    FakeSession? as,
    Map<String, String> headers = const {},
  }) async => _decode(
    await engine.dispatch(
      as ?? staff,
      _request(method, path, body: body, query: query, headers: headers),
    ),
  );

  group('the request', () {
    test('a signed-in staff member creates and reads a book', () async {
      final created = await call(
        'POST',
        '/api/book',
        body: {'title': 'Moominland', 'priceInCents': 1200},
      );
      expect(created.status, 201);

      final page = _json(
        await call(
          'POST',
          '/api/book/query',
          body: const BeakQuerySpec(table: 'book').toJson(),
        ),
      );
      expect(page['total'], 1);
    });

    test('a column the model does not declare never leaves', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'book',
          values: {
            'id': 'b1',
            'title': 'Secret',
            'priceInCents': 1,
            'secret': 'do-not-leak',
          },
        ),
      );

      final one = await call('GET', '/api/book/b1');

      expect(one.status, 200);
      expect(one.body, isNot(contains('do-not-leak')));
      expect(_json(one)['values'], isNot(contains('secret')));
    });

    test('the response carries no hop-by-hop headers', () async {
      final response = await call('GET', '/api/book/nobody');

      final names = response.headers.keys.map((key) => key.toLowerCase());
      expect(names, isNot(contains('content-length')));
      expect(names, isNot(contains('transfer-encoding')));
      expect(names, contains('content-type'));
    });
  });

  group('who may call', () {
    test('an anonymous session is a 401 before Beak runs', () async {
      final response = await call(
        'GET',
        '/api/book/b1',
        as: FakeSession(database: null, authenticated: null),
      );
      expect(response.status, 401);
      expect(_json(response)['code'], 'authentication');
    });

    test('a resolver that answers null is a 403', () async {
      final refusing = BeakServerpodEngine(
        registry: createBookshopRegistry(),
        policy: _policy(),
        adapter: adapter,
        principal: (session, auth) => null,
      );
      final response = _decode(
        await refusing.dispatch(staff, _request('GET', '/api/book/b1')),
      );
      expect(response.status, 403);
    });

    test('a resolver may refuse with its own message', () async {
      final refusing = BeakServerpodEngine(
        registry: createBookshopRegistry(),
        policy: _policy(),
        adapter: adapter,
        principal: (session, auth) => auth.userIdentifier == 'user-1'
            ? throw const BeakAuthorizationException('Suspended.')
            : throw const BeakAuthenticationException('Expired.'),
      );
      final forbidden = _decode(
        await refusing.dispatch(staff, _request('GET', '/api/book/b1')),
      );
      expect(forbidden.status, 403);
      expect(_json(forbidden)['message'], 'Suspended.');

      final other = FakeSession(
        authenticated: signedIn({}, userIdentifier: 'u2'),
      );
      final expired = _decode(
        await refusing.dispatch(other, _request('GET', '/api/book/b1')),
      );
      expect(expired.status, 401);
    });

    test(
      'the principal is the session user with its scopes as roles',
      () async {
        final recording = _Recording();
        final probe = BeakServerpodEngine(
          registry: createBookshopRegistry(),
          policy: recording,
          adapter: adapter,
        );

        await probe.dispatch(staff, _request('GET', '/api/book/b1'));

        expect(
          recording.seen,
          const BeakPrincipal(id: 'user-1', roles: {'beak.admin', _staff}),
        );
      },
    );

    test('a scope without a matching rule is a 403 from the policy', () async {
      final outsider = FakeSession(authenticated: signedIn({'beak.admin'}));
      final response = await call('GET', '/api/book/b1', as: outsider);
      expect(response.status, 403);
    });

    test('a model with no rule is closed, whoever asks', () async {
      final response = await call('GET', '/api/author/a1');
      expect(response.status, 403);
    });

    test('forged headers cannot stand in for the session', () async {
      final outsider = FakeSession(authenticated: signedIn({'beak.admin'}));
      final raw = jsonEncode({
        'v': 1,
        'method': 'GET',
        'path': '/api/book/b1',
        'query': '',
        'headers': {
          'authorization': 'Bearer forged',
          'x-beak-principal': 'root',
          'x-forwarded-for': '10.0.0.1',
        },
        'body': '',
      });

      final response = _decode(await engine.dispatch(outsider, raw));

      expect(response.status, 403);
    });
  });

  group('what may be asked', () {
    test('paths outside /api are a 404', () async {
      for (final path in [
        '/healthz',
        '/api/auth/login',
        '/api/book/../auth/login',
        '/api/%2e%2e/auth',
        '/api//book',
        '/uploads/x.png',
      ]) {
        final response = await call('GET', path);
        expect(response.status, 404, reason: path);
      }
    });

    test('a malformed envelope is a 400', () async {
      final response = _decode(await engine.dispatch(staff, 'not an envelope'));
      expect(response.status, 400);
      expect(_json(response)['code'], 'validation');
    });

    test('the request id header names the log line', () async {
      await call(
        'GET',
        '/api/book/b1',
        headers: {'x-beak-request-id': 'rid-7'},
      );

      expect(
        staff.logs.single.message,
        allOf(contains('beak GET /api/book/b1 -> 404'), contains('[rid-7]')),
      );
    });
  });

  group('graph commits', () {
    test('a commit stores its receipt in the Serverpod table', () async {
      final response = await call(
        'POST',
        '/api/commits',
        body: _plan('save-1').toJson(),
      );

      expect(response.status, 200);
      final receipts = await adapter.select(
        const QueryDescriptor(table: 'beak_commit_receipt'),
      );
      expect(receipts, hasLength(1));
      expect(receipts.single['requestHash'], isNotEmpty);
      expect(receipts.single['resultJson'], contains('save-1'));
    });

    test(
      'a replay answers from the receipt and writes nothing twice',
      () async {
        await call('POST', '/api/commits', body: _plan('save-1').toJson());
        final replay = await call(
          'POST',
          '/api/commits',
          body: _plan('save-1').toJson(),
        );

        expect(replay.status, 200);
        expect(
          await adapter.select(const QueryDescriptor(table: 'book')),
          hasLength(1),
        );
        expect(
          (await call('GET', '/api/commits/save-1')).status,
          200,
          reason: 'recovery reads the same table',
        );
      },
    );

    test('graphOnly models take writes through commits only', () async {
      final guarded = BeakServerpodEngine(
        registry: createBookshopRegistry(),
        policy: _policy(),
        adapter: adapter,
        graphOnly: const [BookModel()],
        preparePlan: (plan, transaction, principal) async => plan,
      );

      final direct = _decode(
        await guarded.dispatch(
          staff,
          _request('POST', '/api/book', body: {'title': 'Direct'}),
        ),
      );
      final committed = _decode(
        await guarded.dispatch(
          staff,
          _request('POST', '/api/commits', body: _plan('save-2').toJson()),
        ),
      );

      expect(direct.status, isNot(201));
      expect(committed.status, 200);
    });

    test(
      'graphOnly without a preparer is refused when the engine is built',
      () {
        expect(
          () => BeakServerpodEngine(
            registry: createBookshopRegistry(),
            policy: _policy(),
            adapter: adapter,
            graphOnly: const [BookModel()],
          ),
          throwsA(isA<BeakConfigurationException>()),
        );
      },
    );
  });

  group('logging', () {
    test('a served request is logged to the session', () async {
      await call('GET', '/api/book/b1');

      expect(staff.logs.single.level, LogLevel.info);
      expect(staff.logs.single.message, contains('beak GET /api/book/b1'));
    });

    test('an unexpected failure is a generic 500 logged as an error', () async {
      final broken = BeakServerpodEngine(
        registry: createBookshopRegistry(),
        policy: _Exploding(),
        adapter: adapter,
      );

      final response = _decode(
        await broken.dispatch(staff, _request('GET', '/api/book/b1')),
      );

      expect(response.status, 500);
      expect(response.body, isNot(contains('policy blew up')));
      final errors = staff.logs.where((log) => log.level == LogLevel.error);
      expect(errors.map((log) => log.exception), contains(isA<StateError>()));
    });
  });

  test('the receipts default to the Serverpod model', () {
    expect(engine.frameworkTables, same(beakServerpodFrameworkTables));
    expect(engine.frameworkTables.receipts.table, 'beak_commit_receipt');
    expect(engine.registry.byTable('book'), isNotNull);
  });
}
