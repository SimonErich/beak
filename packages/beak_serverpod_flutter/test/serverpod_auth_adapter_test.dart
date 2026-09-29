import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart';

class _Client extends Mock implements ServerpodClientShared {}

class _Session extends Mock implements FlutterAuthSessionManager {}

class _Email extends Mock implements EndpointEmailIdpBase {}

class _Identity extends BeakAuthIdentity {
  const _Identity({super.canAccessPanel}) : super(id: 'domain');
}

final _id = UuidValue.fromString('00000000-0000-0000-0000-000000000001');
AuthSuccess _success([String token = 'token']) => AuthSuccess(
  authStrategy: 'email',
  token: token,
  authUserId: _id,
  scopeNames: {},
);

void main() {
  late _Client client;
  late _Session session;
  late _Email endpoint;
  late ValueNotifier<AuthSuccess?> authInfo;
  setUpAll(() => registerFallbackValue(_success()));
  setUp(() {
    client = _Client();
    session = _Session();
    endpoint = _Email();
    authInfo = ValueNotifier(null);
    when(() => session.authInfoListenable).thenReturn(authInfo);
    when(
      () => client.getEndpointOfType<EndpointEmailIdpBase>(),
    ).thenReturn(endpoint);
    when(() => session.updateSignedInUser(any())).thenAnswer((call) async {
      final auth = call.positionalArguments.first;
      authInfo.value = switch (auth) {
        final AuthSuccess value => value,
        _ => null,
      };
    });
    when(() => session.signOutDevice()).thenAnswer((_) async {
      authInfo.value = null;
      return false;
    });
    when(
      () => endpoint.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => _success());
  });

  ServerpodAuthAdapter adapter({
    Future<BeakAuthIdentity?> Function(bool)? resolve,
    bool Function(Object)? unauthenticated,
  }) {
    final value = ServerpodAuthAdapter(
      client: client,
      sessionManager: session,
      resolveIdentity: resolve,
      isUnauthenticated: unauthenticated,
    );
    addTearDown(value.dispose);
    return value;
  }

  test('login preserves the committed domain identity subtype', () async {
    final auth = adapter(
      resolve: (signedIn) async => signedIn ? const _Identity() : null,
    );
    await auth.initialize();
    expect(auth.state.value, isA<BeakAuthGuest>());
    expect(
      (await auth.login(
        email: ' user@example.com ',
        password: 'password',
      )).isOk,
      true,
    );
    expect(
      auth.state.value,
      isA<BeakAuthAuthenticated>().having(
        (state) => state.identity,
        'identity',
        isA<_Identity>(),
      ),
    );
    verify(
      () => endpoint.login(email: 'user@example.com', password: 'password'),
    ).called(1);
  });

  test(
    'denied domain access revokes the newly minted device session',
    () async {
      final auth = adapter(
        resolve: (signedIn) async =>
            signedIn ? const _Identity(canAccessPanel: false) : null,
      );
      await auth.initialize();
      final result = await auth.login(
        email: 'org@example.com',
        password: 'password',
      );
      expect(
        result,
        isA<BeakErr<void>>().having(
          (result) => result.error,
          'error',
          isA<BeakAuthorizationException>(),
        ),
      );
      expect(authInfo.value, null);
      expect(auth.state.value, isA<BeakAuthGuest>());
    },
  );

  test(
    'stored session resolves once and ignores refreshed token events',
    () async {
      authInfo.value = _success();
      var calls = 0;
      final auth = adapter(
        resolve: (signedIn) async {
          calls++;
          return signedIn ? const _Identity() : null;
        },
      );
      await auth.initialize();
      authInfo.value = _success('refreshed');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(auth.state.value, isA<BeakAuthAuthenticated>());
    },
  );

  test(
    'ready refresh stays mounted and logout supersedes its response',
    () async {
      authInfo.value = _success();
      final pending = Completer<BeakAuthIdentity?>();
      var deferred = false;
      final auth = adapter(
        resolve: (signedIn) async => !signedIn
            ? null
            : deferred
            ? pending.future
            : const _Identity(),
      );
      await auth.initialize();
      deferred = true;
      final refresh = auth.refresh();
      expect(auth.state.value, isA<BeakAuthAuthenticated>());
      await auth.logout();
      pending.complete(const _Identity());
      await refresh;
      expect(auth.state.value, isA<BeakAuthGuest>());
    },
  );

  test(
    'HTTP 401 stored session clears locally even remote revocation fails',
    () async {
      authInfo.value = _success();
      final auth = adapter(
        resolve: (signedIn) async {
          if (signedIn) {
            throw ServerpodClientUnauthorized();
          }
          return null;
        },
      );
      expect((await auth.initialize()).isOk, true);
      expect(authInfo.value, null);
      expect(auth.state.value, isA<BeakAuthGuest>());
    },
  );

  test('a login response after logout cannot restore credentials', () async {
    final pending = Completer<AuthSuccess>();
    when(
      () => endpoint.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);
    final auth = adapter();
    await auth.initialize();
    final login = auth.login(email: 'person@example.com', password: 'password');
    await auth.logout();
    pending.complete(_success());
    expect((await login).isOk, false);
    expect(authInfo.value, null);
    expect(auth.state.value, isA<BeakAuthGuest>());
  });

  test('logout wins over a login already writing credentials', () async {
    final writing = Completer<void>();
    final releaseWrite = Completer<void>();
    when(() => session.updateSignedInUser(any())).thenAnswer((call) async {
      final value = call.positionalArguments.first;
      if (value case final AuthSuccess credentials) {
        writing.complete();
        await releaseWrite.future;
        authInfo.value = credentials;
      } else {
        authInfo.value = null;
      }
    });
    var signedInResolutions = 0;
    final auth = adapter(
      resolve: (signedIn) async {
        if (!signedIn) return null;
        signedInResolutions++;
        return const _Identity();
      },
    );
    await auth.initialize();
    final login = auth.login(email: 'person@example.com', password: 'password');
    await writing.future;
    final logout = auth.logout();
    releaseWrite.complete();
    await logout;
    expect((await login).isOk, false);
    expect(authInfo.value, null);
    expect(auth.state.value, isA<BeakAuthGuest>());
    expect(signedInResolutions, 0);
  });

  test(
    'initialization completing after disposal does not publish identity',
    () async {
      authInfo.value = _success();
      final pending = Completer<BeakAuthIdentity?>();
      final auth = adapter(resolve: (_) => pending.future);
      final initialization = auth.initialize();
      auth.dispose();
      pending.complete(const _Identity());
      expect((await initialization).isOk, false);
    },
  );

  test(
    'credential rejection remains typed and never creates a session',
    () async {
      when(
        () => endpoint.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        EmailAccountLoginException(
          reason: EmailAccountLoginExceptionReason.invalidCredentials,
        ),
      );
      final auth = adapter();
      await auth.initialize();
      final result = await auth.login(
        email: 'person@example.com',
        password: 'wrong',
      );
      expect(
        result,
        isA<BeakErr<void>>().having(
          (result) => result.error,
          'error',
          isA<BeakAuthenticationException>(),
        ),
      );
      expect(authInfo.value, null);
      expect(auth.state.value, isA<BeakAuthGuest>());
    },
  );

  test(
    'verification responses after form disposal cannot set a password',
    () async {
      final pending = Completer<UuidValue>();
      when(
        () => endpoint.startPasswordReset(email: any(named: 'email')),
      ).thenAnswer((_) => pending.future);
      final auth = adapter();
      await auth.initialize();
      final flow = auth.recovery!();
      final request = flow.start(email: 'person@example.com');
      flow.dispose();
      pending.complete(_id);
      expect((await request).isOk, false);
      expect((await flow.verify(code: '123456')).isOk, false);
      expect((await flow.complete(password: 'new-password')).isOk, false);
    },
  );

  test('host typed revoked errors use the same recovery path', () async {
    authInfo.value = _success();
    final auth = adapter(
      resolve: (signedIn) async {
        if (signedIn) throw const BeakAuthenticationException('archived');
        return null;
      },
      unauthenticated: (error) => error is BeakAuthenticationException,
    );
    await auth.initialize();
    expect(auth.state.value, isA<BeakAuthGuest>());
  });

  test('failed initialization is visible and retry can recover', () async {
    var fail = true;
    final auth = adapter(
      resolve: (_) async {
        if (fail) throw Exception('offline');
        return null;
      },
    );
    expect((await auth.initialize()).isOk, false);
    expect(auth.state.value, isA<BeakAuthFailure>());
    fail = false;
    expect((await auth.refresh()).isOk, true);
    expect(auth.state.value, isA<BeakAuthGuest>());
  });

  test('registration verifies server token before setting password', () async {
    when(
      () => endpoint.startRegistration(email: any(named: 'email')),
    ).thenAnswer((_) async => _id);
    when(
      () => endpoint.verifyRegistrationCode(
        accountRequestId: _id,
        verificationCode: '123456',
      ),
    ).thenAnswer((_) async => 'verified-token');
    when(
      () => endpoint.finishRegistration(
        registrationToken: 'verified-token',
        password: 'new-password',
      ),
    ).thenAnswer((_) async => _success());
    final auth = adapter();
    await auth.initialize();
    final flow = auth.registration!();
    addTearDown(flow.dispose);
    expect((await flow.complete(password: 'new-password')).isOk, false);
    expect((await flow.start(email: 'person@example.com')).isOk, true);
    expect((await flow.verify(code: '123456')).isOk, true);
    expect((await flow.complete(password: 'new-password')).isOk, true);
    expect(auth.state.value, isA<BeakAuthAuthenticated>());
  });

  test('recovery completes reset and returns to guest login', () async {
    when(
      () => endpoint.startPasswordReset(email: any(named: 'email')),
    ).thenAnswer((_) async => _id);
    when(
      () => endpoint.verifyPasswordResetCode(
        passwordResetRequestId: _id,
        verificationCode: '123456',
      ),
    ).thenAnswer((_) async => 'reset-token');
    when(
      () => endpoint.finishPasswordReset(
        finishPasswordResetToken: 'reset-token',
        newPassword: 'new-password',
      ),
    ).thenAnswer((_) async {});
    final auth = adapter();
    await auth.initialize();
    final flow = auth.recovery!();
    addTearDown(flow.dispose);
    await flow.start(email: 'person@example.com');
    await flow.verify(code: '123456');
    expect((await flow.complete(password: 'new-password')).isOk, true);
    expect(auth.state.value, isA<BeakAuthGuest>());
    verifyNever(
      () => endpoint.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });
}
