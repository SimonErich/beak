---
title: Auth and idle-lock
description: How the panel signs in against the generated /api/auth/login, what BeakAuthConfig overrides, and how to auto-lock the shell after inactivity.
---

# Auth and idle-lock

After this page you can put a real sign-in flow in front of the panel, back it
with the server's own accounts and sessions, and have the shell lock itself
after a stretch of inactivity.

Auth has two halves, and only one of them is the panel. The server decides who
may sign in and what each of them may see. The panel signs in against the
server, keeps the session, and sends it with every later request. The second
half needs no configuration at all.

## Turning auth on

Configure auth on the server, in `lib/server.dart`. `BeakAuthSessions` mounts
`POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`, and the
guard turns a presented token back into a principal:

```dart title="examples/store/lib/server.dart"
BeakServer beakServer(BeakServerDefaults defaults) {
  final String secret =
      defaults.environment['AUTH_SECRET'] ?? 'store-dev-secret';
  final store = InMemoryTokenSessionStore();
  return defaults.build(
    policy: const StorePolicy(),
    authSessions: BeakAuthSessions(
      store: store,
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'ada@example.com',
          passwordHash: hashBeakPassword('espresso', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userAda,
            roles: {'staff'},
          ),
        ),
        BeakUserAccount(
          username: 'linus@example.com',
          passwordHash: hashBeakPassword('grinder', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userLinus,
            roles: {'customer'},
          ),
        ),
      ],
    ),
    authGuard: TokenSessionAuthGuard(store),
  );
}
```

That is the whole of it. The store example has no `lib/auth.dart`, no
`BeakAuthConfig`, and no callback anywhere, and its panel still signs people in:
`/login` is mounted on every panel, and with no `onLogin` it posts to the
generated endpoint through the registered session store.

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
// With no callback the panel signs in against the generated
// `/api/auth/login`: a project that configured server-side auth
// does not also have to wire the request that uses it.
final bool signedIn =
    await (auth?.onLogin?.call(email, password) ??
        beakLocator<BeakSessionStore>().signIn(
          username: email,
          password: password,
        ));
if (signedIn && context.mounted) {
  context.go('/');
}
```

The session store is a singleton the panel registers at startup, and the HTTP
client already reads its token:

```dart title="packages/beak_frontend/lib/src/auth/beak_session_store.dart"
/// Holds the panel's signed-in session for the lifetime of the app.
///
/// Registered as a singleton by `registerBeakDependencies`, which also points
/// the [BeakClient]'s token provider at it — so signing in through
/// [BeakSessionStore.signIn] authenticates every later request without any
/// wiring in between.
```

!!! note "What just happened"
    - The server minted a session token and returned it with the principal.
    - `BeakSessionStore` remembered it; the client sends it as a Bearer token.
    - Wrong credentials return `false` and the sign-in form says so. A broken
      server still throws, because a 500 is not a wrong password.
    - Nothing in the panel had to be configured for any of that.

### What `lib/auth.dart` adds

Add the convention file when you want more than a login screen: a register
route, a recover route, idle-lock, or credentials checked somewhere that is not
the Beak server.

```bash
beak eject auth
```

That writes `lib/auth.dart`, already returning Beak's default so it compiles and
changes nothing until your first edit:

```dart
import 'package:beak/panel.dart';

/// Which auth routes the panel mounts, and what they call.
///
/// With no `onLogin`, the panel signs in against the generated
/// `/api/auth/login` and remembers the session, so a project whose
/// `lib/server.dart` configures auth needs nothing here. Supply one to
/// authenticate somewhere else.
BeakAuthConfig beakAuth() => const BeakAuthConfig();
```

`beak prepare` notices the file and passes the result to the panel. A bare
`const BeakAuthConfig()` mounts `/register` and `/recover` beside the `/login`
you already had; every field is optional from there:

```dart title="packages/beak_frontend/lib/src/panel/beak_auth_config.dart"
const BeakAuthConfig({
  this.register = true,
  this.recover = true,
  this.onLogin,
  this.onRegister,
  this.onRecover,
  this.idleLockTimeout,
  this.lockUserName,
  this.onUnlock,
});
```

The superdashboard wires the whole surface by hand, because it has no accounts
to check against and wants every screen reachable. It does it from
`lib/panel.dart` rather than `lib/auth.dart`, since that file is already
changing several other panel-level things:

```dart title="examples/superdashboard/lib/panel.dart"
auth: BeakAuthConfig(
  // Demo sign-in is cosmetic — the panel is not guarded.
  onLogin: (email, password) async => true,
  onRegister: (name, email, password) async => true,
  onRecover: (email) async => true,
  // Auto-lock after inactivity; the lock screen is also always at /lock.
  idleLockTimeout: const Duration(minutes: 10),
  lockUserName: 'Aisha Rahman',
  onUnlock: (password) async => true,
),
```

!!! warning "The panel is not the boundary"
    Signing in is real, but nothing in the panel refuses to render a page. There
    is no redirect that forces a visitor to `/login`; an anonymous visitor sees
    the shell and the API refuses the data. That is the right way round, because
    a client that skips the panel skips any check the panel made. Enforcement
    lives in the server's `BeakPolicy`: the store's makes the catalog public,
    scopes a customer to their own orders, and lets only staff delete. See
    [Auth and policies](../backend/auth-and-policies.md).

## The flow callbacks

Each flow callback returns a `Future<bool>`: `true` means success, and Beak
advances the flow. There are three of them, plus `onUnlock` for the lock screen
further down. Their signatures are fixed, so the auth page always calls them the
same way.

```dart title="packages/beak_frontend/lib/src/panel/beak_auth_config.dart"
/// Validates a sign-in; returns `true` on success.
final Future<bool> Function(String email, String password)? onLogin;

/// Handles a registration; returns `true` on success.
final Future<bool> Function(String name, String email, String password)?
onRegister;

/// Handles a password-recovery request; returns `true` on success.
final Future<bool> Function(String email)? onRecover;
```

What each success does differs, because the destinations differ:

| Route | Callback | On `true` | Callback omitted |
| --- | --- | --- | --- |
| `/login` | `onLogin(email, password)` | Navigate into the panel at `/`. | Signs in against `/api/auth/login`. |
| `/register` | `onRegister(name, email, password)` | Navigate into the panel at `/`. | Automatic success. |
| `/recover` | `onRecover(email)` | Return to `/login` (the reset email went out). | Automatic success. |
| `/lock` | `onUnlock(password)` | Navigate back into the panel at `/`. | Any password unlocks. |

`onLogin` is the odd one out, and deliberately: it is the only callback with a
generated endpoint behind it, so omitting it does the right thing instead of
nothing. Supply it to authenticate against an SSO provider, your own token
exchange, or anything else that is not the Beak server.

The auth screens are mounted outside the shell, so they render full-page with no
sidebar. Each one is obers_ui's `OiAuthPage`.

## Idle-lock

Set `idleLockTimeout` and the panel locks itself after that much inactivity
inside the shell. Leave it null and the panel never auto-locks. This is the one
part of auth that does need a `BeakAuthConfig`: no `lib/auth.dart`, no timer.

```dart title="packages/beak_frontend/lib/src/panel/beak_auth_config.dart"
/// When set, the panel locks to `/lock` after this much inactivity inside
/// the shell; `null` never auto-locks.
final Duration? idleLockTimeout;

/// The name shown on the lock screen (defaults to the panel title).
final String? lockUserName;

/// Validates the unlock password; returns `true` to unlock. `null` accepts
/// any password (demo-friendly).
final Future<bool> Function(String password)? onUnlock;
```

Both pointer activity and keyboard activity reset the countdown, so typing a
long form does not lock the panel mid-keystroke and destroy the unsaved input:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
// Keyboard events travel the focus pipeline, not the pointer pipeline
// — without this hook, typing continuously in a form still locks the
// panel mid-keystroke and destroys the unsaved input.
bool onKey(KeyEvent event) {
  schedule();
  return false;
}
```

The `/lock` route is mounted on every panel, `auth` or not, so you can send a
user there yourself (a "lock now" button, for instance). The lock screen shows
`lockUserName`, falling back to the panel title, and validates the entered
password through `onUnlock`:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
GoRoute(
  path: '/lock',
  builder: (context, state) => OiAuthPage.lock(
    label: config.title,
    userName: auth?.lockUserName ?? config.title,
    onUnlock: (password) async {
      final bool unlocked =
          await (auth?.onUnlock?.call(password) ??
              Future<bool>.value(true));
      if (unlocked && context.mounted) {
        context.go('/');
      }
      return unlocked;
    },
  ),
),
```

!!! note "What just happened"
    - `idleLockTimeout: const Duration(minutes: 10)` locks after ten idle
      minutes.
    - `onUnlock` returning `true` sends the user back to `/`. A `null` `onUnlock`
      accepts any password, which is demo-friendly but not something you ship.
    - Locking is a client convenience, not a security boundary. The data behind
      the lock screen is only as safe as the policy guarding it.

## Reference

`BeakAuthConfig` fields and defaults:

| Field | Type | Default | Purpose |
| --- | --- | --- | --- |
| `register` | `bool` | `true` | Whether `/register` is mounted. |
| `recover` | `bool` | `true` | Whether `/recover` is mounted. |
| `onLogin` | `Future<bool> Function(String, String)?` | `null` | Validates a sign-in. Null signs in against `/api/auth/login`. |
| `onRegister` | `Future<bool> Function(String, String, String)?` | `null` | Handles a registration. Null succeeds. |
| `onRecover` | `Future<bool> Function(String)?` | `null` | Handles a recovery request. Null succeeds. |
| `idleLockTimeout` | `Duration?` | `null` | Inactivity before auto-lock; null disables it. |
| `lockUserName` | `String?` | `null` | Name on the lock screen; falls back to the title. |
| `onUnlock` | `Future<bool> Function(String)?` | `null` | Validates the unlock password. Null accepts any. |

Which routes exist, and when:

| Route | Mounted when |
| --- | --- |
| `/login` | Always. |
| `/lock` | Always. |
| `/register` | The panel has a `BeakAuthConfig` (from `lib/auth.dart` or `lib/panel.dart`) and `register` is `true`. |
| `/recover` | The panel has a `BeakAuthConfig` and `recover` is `true`. |

## Continue reading

- [Auth and policies](../backend/auth-and-policies.md) the server-side accounts, sessions, and row policy that make signing in mean something.
- [Maintenance and coming soon](maintenance-and-coming-soon.md) the other pair of config-mounted, outside-the-shell routes.
- [The navigation shell](the-navigation-shell.md) the shell the auth screens sit outside of, and where idle-lock counts inactivity.
- [Escape hatches](../models/escape-hatches.md) `lib/auth.dart` among the other convention files.
- [Configuration options](../reference/configuration-options.md) every `BeakPanelConfig` field in one table.
