---
title: Authentication and scopes
description: Wire Serverpod's email sign-in into the Beak panel, gate the admin endpoint with the beak.admin scope, and know when a grant or a revoke takes effect.
type: guide
audience: [expert]
status: stable
---

# Authentication and scopes

After this page you can say who is allowed through each door between a browser and your data, grant and revoke panel access, and predict how long a revoked admin keeps working. Serverpod owns credentials, tokens and scopes. Beak adds sign-in screens on top and, on the admin app path, a gate and a policy behind them.

## At a glance

Three checks stand between a browser and a row, and only the last two are authority.

| Check | Where | What it decides |
| --- | --- | --- |
| Identity resolver | In the admin app, `ServerpodIdentityResolver` | Whether the sign-in screen lets an account into the panel shell. Presentation only |
| Endpoint gate | On the server, `BeakAdminGate` | Signed in, and holding the `beak.admin` scope. Serverpod answers 401 or 403 before any Beak code runs |
| Policy | On the server, `BeakPolicies` | Which models and operations the principal's roles may use. Deny by default |

The scope names are the contract between them:

- `beak.admin` (`BeakScopes.admin`) opens the tunnel and grants nothing. It is deliberately not `Scope.admin`, so your app's own admins do not get the panel by accident.
- `bookshop.staff` (an app scope) is what the example's policy reads. The default principal resolver turns every scope name into a Beak role, which is why `BeakAccess.role('bookshop.staff')` takes the scope's name.

### The server

The sign-in is Serverpod's template: JWT tokens and the email identity provider, with two endpoints the template already has.

```dart title="examples/serverpod/bookshop_server/lib/server.dart"
void initializeBookshopAuth(Serverpod pod) {
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
    identityProviderBuilders: [
      // Configure the email identity provider for email/password
      // authentication. The default setup works with Serverpod Cloud without
      // configuration; use `EmailIdpConfigFromPasswords` for your own sender.
      ServerpodCloudEmailIdpConfig(
        appDisplayName: 'bookshop',
      ),
    ],
  );
}
```

The function is top-level because `bin/beak_admin.dart` calls it too. In development the server prints the verification codes to its log. Deployed, configure a real sender.

The scope and the gate:

```dart title="packages/beak_serverpod_server/lib/src/beak_admin_gate.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_admin_gate.dart:BeakScopes"
```

```dart title="packages/beak_serverpod_server/lib/src/beak_admin_gate.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_admin_gate.dart:BeakAdminGate"
```

### The app

`ServerpodAuthAdapter` gives Beak's login, registration and recovery screens a Serverpod session. It owns no credentials: Serverpod keeps secure storage and token refresh.

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_auth_adapter.dart"
ServerpodAuthAdapter({
  required this.client,
  required this.sessionManager,
  this.resolveIdentity,
  ServerpodAuthExceptionMapper? exceptionMapper,
  this.isUnauthenticated,
}) : _errors = ServerpodAuthErrors(exceptionMapper) {
  sessionManager.authInfoListenable.addListener(_onAuthChanged);
}
```

Build it in `main`, after the client has restored its stored session, and call `initialize()` before `runApp`:

```dart title="examples/serverpod/bookshop_admin/lib/main.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/main.dart:main"
```

`resolveIdentity` is where the app decides who may open the panel. Return `null` for a guest, or a `BeakAuthIdentity` whose `canAccessPanel` comes from the token's scopes:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart:bookshopAdminIdentity"
```

Then hand the adapter to the panel. Registration and recovery are off until you opt in, and each also needs the adapter to support it:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart:bookshopAdminPanel"
```

### Sign-in, registration, recovery

| Flow | Calls on the generated email endpoint | Result |
| --- | --- | --- |
| Sign in | `login(email:, password:)` | An `AuthSuccess` that the session manager stores. If the resolved identity has `canAccessPanel: false`, the adapter signs the device out again and reports `The account cannot access this panel.` |
| Register | `startRegistration`, `verifyRegistrationCode`, `finishRegistration` | Signs the new account in through the same identity check. It has no scopes yet, so it cannot open the panel |
| Recover | `startPasswordReset`, `verifyPasswordResetCode`, `finishPasswordReset` | Sets the new password and returns to the sign-in screen, without minting a session |

Request ids and verified tokens stay inside one per-form flow object and never reach a widget. Credential writes are ordered, so a logout that starts while a login is still persisting wins.

### Granting and revoking

A new account is a customer, not an admin. `bin/beak_admin.dart` in the server package is the way in:

```console
cd bookshop_server
dart run bin/beak_admin.dart grant you@example.com
dart run bin/beak_admin.dart revoke you@example.com
```

Use `dart run`, not `dart bin/beak_admin.dart`: only `dart run` builds the Argon2 native asset. The script goes through Serverpod (`withSession` and `AuthServices`), never through SQL. It merges instead of replacing, because `authUsers.update(scopes:)` replaces the whole set:

```dart title="examples/serverpod/bookshop_server/bin/beak_admin.dart"
final Set<String> after = switch (command) {
  'grant' => {...before, ...adminNames},
  _ => before.difference(adminNames),
};
await users.update(
  session,
  authUserId: account.authUserId,
  scopes: {for (final name in after) Scope(name)},
);
```

`grant` adds `beak.admin` and `bookshop.staff`. `revoke` removes both and then revokes every token of the user, because removing a scope alone ends nothing while the client keeps refreshing. It prints the scope set before and after, and exits with 64 on a wrong invocation and 1 when no email account exists (`No email account for <email>. Sign up first.`).

## Rules and limits

| Rule | Detail |
| --- | --- |
| A grant takes effect on the next sign-in | Scopes are copied into a token when it is issued. The panel reads them from the token Serverpod issued at sign-in, so sign out and in again |
| A revoke is bounded by the access-token lifetime | `revoke` revokes every token of the user, which ends the refresh tokens, so the client cannot renew. An access token issued before stays valid until it expires: 10 minutes by default (`JwtConfig.accessTokenLifetime`), 14 days for the refresh token. Shorten the access token with `JwtConfigFromPasswords(accessTokenLifetime: ...)` if that window is too long |
| The app-side check is convenience | `canAccessPanel` keeps a signed-in customer on the sign-in screen instead of in a shell of 403s. The gate and the policy decide every request |
| Public registration never grants access | It is off unless `register: true`, and an account it creates holds no scope. The example turns it on so the first account can be created in the panel; a deployed admin usually leaves it off |
| Only the email provider is tested | The adapter calls the generated email endpoint, and the script looks accounts up through `EmailIdp`. Another provider needs its own adapter |
| Only JWT is tested | The tunnel reads `session.authenticated` and never looks at the token type, but nothing here tests server-side sessions or cookie mode |
| Rejected sessions are cleared | A 401 while resolving the identity, or an error your `isUnauthenticated` recognizes, signs the device out and resolves to guest. A data request the gate answers with 401 does the same: the panel calls the adapter's `logout()`, so a revoked admin lands on the sign-in screen at its next request instead of reading errors. Local logout works even if remote revocation fails |
| Beak sends no bearer token | The Serverpod client authenticates the `dispatch` call. Do not add an `Authorization` header |
| Passwords and rate limits are Serverpod's | The panel shows `Too many sign-in attempts.` and `Invalid credentials.`; it stores no password policy of its own |
| Keep the `serverpod*` pins identical | See [Version compatibility](versions.md) |

Errors the adapter maps, as Beak's typed exceptions (the panel shows their messages, never the transport's):

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_auth_errors.dart"
BeakException map(Object error, StackTrace stackTrace) => switch (error) {
  final BeakException error => error,
  EmailAccountLoginException(
    reason: EmailAccountLoginExceptionReason.tooManyAttempts,
  ) =>
    const BeakConflictException('Too many sign-in attempts.'),
  EmailAccountLoginException() => const BeakAuthenticationException(
    'Invalid credentials.',
  ),
  EmailAccountRequestException(
    reason: EmailAccountRequestExceptionReason.tooManyAttempts,
  ) ||
  EmailAccountPasswordResetException(
    reason: EmailAccountPasswordResetExceptionReason.tooManyAttempts,
  ) => const BeakConflictException('Too many verification attempts.'),
  EmailAccountRequestException() ||
  EmailAccountPasswordResetException() => const BeakValidationException(
    'The verification request or password was rejected.',
  ),
  ServerpodClientHttpException(statusCode: 401) =>
    const BeakAuthenticationException(
      'The device session is no longer valid.',
    ),
  ServerpodClientHttpException(statusCode: 403) =>
    const BeakAuthorizationException('Access denied.'),
  _ =>
    mapper?.call(error, stackTrace) ??
        const BeakConfigurationException('Authentication transport failed.'),
};
```

Your own domain exceptions go through `exceptionMapper`, which runs after these.

## Verify it

The adapter's tests inject generated endpoint and session fakes and cover the identity checks, races and every email step. The example proves the gate, the tunnel and the sign-in screens:

```console
$ cd packages/beak_serverpod_flutter && flutter test
00:00 +20: All tests passed!
$ cd examples/serverpod/bookshop_server && dart test
$ cd examples/serverpod/bookshop_admin && flutter test
```

The server suite includes the cases that matter here: anonymous is 401, a signed-in user without `beak.admin` is 403 even with `Scope.admin`, and `beak.admin` alone is 403 on every table. A widget test proves that an account without `beak.admin` stays on the sign-in screen after a correct password. A live test (`test_live/admin_flow_test.dart`, needs a running server) signs up by email and grants and revokes access with the script.

## Reference

| Symbol | Package | What it is |
| --- | --- | --- |
| `BeakScopes.admin` | `beak_serverpod_server` | The `beak.admin` scope |
| `BeakAdminGate` | `beak_serverpod_server` | Mixin on `Endpoint`: `requireLogin` and `requiredScopes` |
| `BeakServerpodPrincipal.fromScopes` | `beak_serverpod_server` | The default principal: user id, every scope name as a role |
| `BeakServerpodPrincipalResolver` | `beak_serverpod_server` | `FutureOr<BeakPrincipal?> Function(Session, AuthenticationInfo)`; `null` is a 403, a thrown `BeakAuthenticationException` or `BeakAuthorizationException` is a 401 or 403 with your message |
| `ServerpodAuthAdapter` | `beak_serverpod_flutter` | Beak's `BeakAuthAdapter` over a Serverpod client and `FlutterAuthSessionManager` |
| `ServerpodIdentityResolver` | `beak_serverpod_flutter` | `Future<BeakAuthIdentity?> Function(bool signedIn)` |
| `ServerpodAuthExceptionMapper` | `beak_serverpod_flutter` | `BeakException Function(Object error, StackTrace stackTrace)` |
| `BeakAuthConfig` | `beak_frontend` | `adapter`, `register`, `recover`, and the idle-lock options |

Mounting the panel inside a host app's own `go_router` uses `BeakAuthRouterRefresh`, `beakAuthRoutes` and `beakPanelRoutes`; [Auth and idle-lock](../panel/auth-and-idle-lock.md) has the screens and the lock.

## Continue reading

- [Auth and idle-lock](../panel/auth-and-idle-lock.md): the panel-side screens, idle lock and route gates.
- [Auth and policies](../backend/auth-and-policies.md): how `BeakPolicies` and roles decide on the server.
- [Troubleshooting](troubleshooting.md): the 401 and 403 cases, by symptom.
