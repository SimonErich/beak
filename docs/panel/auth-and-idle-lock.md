---
title: Auth and idle-lock
description: Configure Beak-owned login, registration and password recovery over one backend session authority.
---

# Auth and idle-lock

Beak owns the standard auth screens, their pending/error state, English/German
labels and route transitions. A `BeakAuthAdapter` owns the existing backend session.
The application maps its account and permission rules into a `BeakAuthIdentity`;
it does not need login screens, transport code or a second token store.

## Configuration

```dart
BeakAuthConfig(
  adapter: authAdapter,
  register: false,
  recover: true,
)
```

Set this on `BeakPanelConfig.auth`. Registration and recovery default to **off**.
An enabled route also requires the matching adapter capability. Missing operations
never report success and cannot be reached by typing their URL.

| Route | Requirement | Workflow |
| --- | --- | --- |
| `/login` | Always available | Email/password, then resolved panel access |
| `/register` | `register: true` and `adapter.registration` | Email, verification code, new password |
| `/recover` | `recover: true` and `adapter.recovery` | Email, verification code, new password, return to login |
| `/lock` | Existing lock surface | Explicit `onUnlock` callback; absence rejects |

`BeakAuthPage` composes obers_ui controls and uses `BeakLocalizations` for all
framework text. Errors are rendered by their typed category; raw transport or
server exception descriptions are never displayed in the auth form. A backend
continues to enforce its password policy and rate limits.

For a standalone panel, configure `BeakPanelConfig.locale`, `supportedLocales`
and application `localizationsDelegates` directly. `BeakPanel` supplies the root
app and always installs Beak's translations alongside those delegates. No host
app wrapper is needed just to localize resource labels or select a language.

## Serverpod

Use `beak_serverpod_flutter` beside the data-only `beak_serverpod` package. It uses
the host's existing generated client and `FlutterAuthSessionManager`:

```dart
final auth = ServerpodAuthAdapter(
  client: client,
  sessionManager: sessionManager,
  resolveIdentity: resolvePanelIdentity,
  exceptionMapper: mapDomainAuthException,
  isUnauthenticated: isDomainUnauthenticated,
);
await auth.initialize();

final authConfig = BeakAuthConfig(adapter: auth, recover: true);
```

`resolvePanelIdentity(bool signedIn)` returns `Future<BeakAuthIdentity?>`. Return
null for a guest; return the signed-in identity with `canAccessPanel` derived from
server permissions. Identity classes may extend `BeakAuthIdentity` to hold their
existing typed account projection. The adapter preserves that exact instance,
committing it only after checking that the request has not been superseded.
Do not mutate a second app account snapshot inside the asynchronous resolver.

Initialize after the session manager has loaded secure storage and host
resolution dependencies are ready. Dispose the adapter when its owning app or DI
scope ends. Registration is still off unless the panel explicitly enables it;
creating an account does not grant admin permissions. The backend remains the
permission boundary.

The adapter calls the generated email IDP endpoint for login and all three
registration/recovery steps. Request IDs and verified tokens remain inside a
per-form flow. Recovery sets the new password and returns to sign-in; it does
not automatically create a new session. Delivery of verification emails remains
configured by the Serverpod server.

Stored-session initialization, duplicate JWT events, sign-out races and revoked
sessions are handled by the adapter. Permission refresh keeps a ready form
mounted. HTTP 401 and host-recognized unauthenticated exceptions clear the device
session and resolve guest state, including when remote revocation fails. Other
resolution failures remain an error state with retry/sign-out recovery.
Credential writes are ordered: signing out while a login is persisting cannot
restore the older session afterward.

## Standalone HTTP panels

With `auth: const BeakAuthConfig()`, the standalone panel uses `BeakSessionStore`
over `BeakClient`. It authenticates against `/api/auth/login`, retains the returned
bearer token and attaches it to subsequent requests; logout clears locally and
calls `/api/auth/logout`. Configure real accounts and authorization on the server
using `BeakAuthSessions` and a `BeakPolicy`.

The HTTP adapter currently implements login/logout only. Setting `register` or
`recover` cannot invent missing backend endpoints. Implement a matching adapter
capability when adding those server workflows. Leaving `config.auth` null keeps
the panel available without a client-side auth gate; server policies still apply.

## Other backends

Implement `BeakAuthAdapter` with a live `ReadonlySignal<BeakAuthState>` and typed
`Future<BeakResult<void>>` operations for `login`, `logout` and `refresh`. This is
the catch boundary: transport exceptions become typed Beak failures here rather
than escaping into a widget.

The optional `registration` and `recovery` getters return factories for new
`BeakEmailVerificationFlow` instances. Each flow implements `start(email:)`,
`verify(code:)`, `complete(password:)` and `dispose()`. State and verification
secrets belong to that instance, not a global widget or URL. A backend that uses
a different workflow can provide a custom screen rather than pretending a
verification operation succeeded.

## Existing application routers

Use the exported route/gate helpers with the host's existing router and root app:

```dart
final refresh = BeakAuthRouterRefresh(auth);
final router = GoRouter(
  refreshListenable: refresh,
  redirect: (_, state) => refresh.redirect(state.uri.path),
  routes: [
    ...beakAuthRoutes(config),
    ...beakPanelRoutes(config),
  ],
);
```

`beakPanelRoutes` wraps the configured panel in `BeakAuthGate`; auth routes stay
outside that gate so login permission resolution does not unmount the form.
The host supplies its `/403` error route when embedding. Dispose both router and
refresh bridge at teardown. `BeakPanel` wires these helpers itself for standalone
use. Read/write resource capabilities are still independently checked at direct
resource routes and on the server.
Changing the authenticated identity rebuilds protected routes and their form
state even when the URL stays the same. A permission refresh for the same
identity preserves form controllers when access still allows the route.
`ReferenceCache` invalidates cached relationship labels on auth-state changes;
late responses from the previous account cannot populate the new account's
cache. Persisted drafts need an account-specific storage context as described in
[Drafts and review](drafts-and-review.md).

The shell supplies a localized logout action when authentication is configured
and `shellActions` is null. Supplying `shellActions` replaces that default;
include `BeakLogoutButton(adapter: auth)` in the returned list if custom actions
should retain it.

## Idle lock

`idleLockTimeout` starts a pointer/keyboard inactivity timer in the shell.
`lockUserName` controls the lock screen's name. Supply `onUnlock` to verify the
password; an absent callback rejects every attempt. This lock is a UI convenience,
not a substitute for backend session expiry or authorization.

## Verification

The frontend auth tests exercise localized login and email verification controls,
backend denial/retry, disabled direct routes, HTTP sessions, logout and pending
operation disposal. The Serverpod adapter tests cover generated RPC calls,
permission projection, stored-session recovery, refresh races and typed failures.

```sh
cd packages/beak_frontend
flutter test test/src/auth test/src/panel/beak_screen_routing_test.dart
cd ../beak_serverpod_flutter
flutter test
```

## Continue reading

- [Auth and policies](../backend/auth-and-policies.md)
- [The navigation shell](the-navigation-shell.md)
- [Configuration options](../reference/configuration-options.md)
