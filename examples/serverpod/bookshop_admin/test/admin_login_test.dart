import 'dart:convert';

import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:bookshop_admin/src/bookshop_admin.dart';
import 'package:bookshop_client/bookshop_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'support/fake_bookshop_server.dart';

const _email = 'moominmamma@dog-eared.test';
const _password = 'Moomin-Troll-2026!';

final class _MemoryStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

/// The Serverpod server as the generated client sees it over HTTP: the email
/// IDP's `login`, the JWT refresh endpoint and the gated
/// `beakAdmin.dispatch` (401 for a stale token, 403 without `beak.admin`),
/// answered by [FakeBookshopServer] behind the gate.
final class _FakeServerpod {
  _FakeServerpod(this.beak, {required this.scopes});

  final FakeBookshopServer beak;
  final Set<String> scopes;

  /// Every endpoint path called, in order (`/emailIdp/login`).
  final List<String> calls = [];

  /// The Authorization header of each `beakAdmin.dispatch` call.
  final List<String?> dispatchAuthorizations = [];

  int _issued = 0;

  String get currentToken => 'access-$_issued';

  String _issue() => SerializationManager.encodeForProtocol(
    AuthSuccess(
      authStrategy: 'jwt',
      token: 'access-${++_issued}',
      tokenExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      refreshToken: 'refresh-$_issued',
      authUserId: UuidValue.fromString('0199a0e8-0000-7000-8000-000000000001'),
      scopeNames: scopes,
    ),
  );

  late final http.Client transport = MockClient((request) async {
    calls.add(request.url.path);
    switch (request.url.path) {
      case '/emailIdp/login':
        final Object? args = jsonDecode(request.body);
        if (args case {'email': _email, 'password': _password}) {
          return http.Response(_issue(), 200);
        }
        return http.Response('', 401);
      case '/jwtRefresh/refreshAccessToken':
        return http.Response(_issue(), 200);
      case '/beakAdmin/dispatch':
        final String? authorization = request.headers['authorization'];
        dispatchAuthorizations.add(authorization);
        if (authorization != wrapAsBearerAuthHeaderValue(currentToken)) {
          return http.Response('', 401);
        }
        if (!scopes.contains(beakAdminScopeName)) {
          return http.Response('', 403);
        }
        final Object? args = jsonDecode(request.body);
        if (args case {'request': final String envelope}) {
          return http.Response(jsonEncode(await beak.dispatch(envelope)), 200);
        }
        return http.Response('', 400);
    }
    return http.Response('', 404);
  });
}

Future<(_FakeServerpod, ServerpodAuthAdapter)> _pumpAdmin(
  WidgetTester tester, {
  required Set<String> scopes,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fake = _FakeServerpod(
    await FakeBookshopServer.seeded(),
    scopes: scopes,
  );
  final sessionManager = FlutterAuthSessionManager(storage: _MemoryStorage());
  final client = Client(
    'http://localhost:8080/',
    httpClientOverride: fake.transport,
  )..authSessionManager = sessionManager;
  final auth = ServerpodAuthAdapter(
    client: client,
    sessionManager: sessionManager,
    resolveIdentity: bookshopAdminIdentity(sessionManager),
  );
  addTearDown(auth.dispose);
  await auth.initialize();
  await tester.pumpWidget(
    bookshopAdminPanel(dispatch: client.beakAdmin.dispatch, auth: auth),
  );
  await tester.pumpAndSettle();
  return (fake, auth);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, _email);
  await tester.enterText(find.byType(EditableText).last, _password);
  await tester.tap(find.text('Sign in').last);
  await tester.pumpAndSettle();
}

List<String> _texts() => [
  for (final element in find.byType(Text).evaluate())
    if ((element.widget as Text).data case final String text) text,
];

void main() {
  testWidgets('an account without beak.admin stays on the sign-in screen', (
    tester,
  ) async {
    final (fake, _) = await _pumpAdmin(tester, scopes: {});
    expect(find.text('Sign in'), findsWidgets, reason: '${_texts()}');
    await _signIn(tester);
    expect(fake.calls, contains('/emailIdp/login'));
    expect(
      find.text('This account cannot access this panel.'),
      findsOneWidget,
      reason: '${_texts()}',
    );
    // The panel never reached Beak: no dispatch call was made.
    expect(fake.calls, isNot(contains('/beakAdmin/dispatch')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a beak.admin account signs in and Books load through dispatch', (
    tester,
  ) async {
    final (fake, _) = await _pumpAdmin(
      tester,
      scopes: {beakAdminScopeName, 'bookshop.staff'},
    );
    await _signIn(tester);
    await tester.tap(find.text('Books').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Comet in Moominland'),
      findsOneWidget,
      reason: '${_texts()}\n${fake.calls}',
    );
    // Serverpod's client authenticates dispatch with the token it holds...
    expect(fake.dispatchAuthorizations, isNotEmpty);
    expect(fake.dispatchAuthorizations.toSet(), {
      wrapAsBearerAuthHeaderValue('access-1'),
    });
    // ...and the envelope inside carries no credentials at all.
    for (final request in fake.beak.requests) {
      expect(request.headers.keys, isNot(contains('authorization')));
    }
    expect(fake.calls, isNot(contains('/jwtRefresh/refreshAccessToken')));
    expect(tester.takeException(), isNull);
  });
}
