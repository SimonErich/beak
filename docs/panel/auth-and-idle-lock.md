---
title: Auth and idle-lock
description: Configure the panel's login, register, and recover screens with BeakAuthConfig, and auto-lock the shell after inactivity with idleLockTimeout.
---

# Auth and idle-lock

After this page you can put a sign-in flow in front of the panel and have it lock
itself after a stretch of inactivity. You give Beak a `BeakAuthConfig` with a few
callbacks that return `Future<bool>`, and it mounts the login, register, recover,
and lock screens for you, each rendered with obers_ui's `OiAuthPage`.

## Turning auth on

Set `auth` on the config. `/login` is always mounted; `/register` and `/recover`
follow their flags (both default to `true`).

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

The showcase wires all three flows plus idle-lock. In the demo every callback
returns `true`, since the panel is not guarded; in a real app you point them at your
backend.

```dart title="apps/beak_superdashboard/lib/panel/config.dart"
auth: BeakAuthConfig(
  onLogin: (email, password) async => true,
  onRegister: (name, email, password) async => true,
  onRecover: (email) async => true,
  idleLockTimeout: const Duration(minutes: 10),
  lockUserName: 'Aisha Rahman',
  onUnlock: (password) async => true,
),
```

!!! warning "Client auth is cosmetic"
    A `BeakAuthConfig` renders screens and runs your callbacks; it does not by itself
    protect any data. Enforcement lives on the server. Wire these callbacks to a real
    token exchange and pair them with a backend policy. See
    [Auth and policies](../backend/auth-and-policies.md).

## The three callbacks

Each callback returns a `Future<bool>`: `true` means success, and Beak advances the
flow. Their signatures are fixed, so the auth page always calls them the same way.

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

| Route | Callback | On `true` |
| --- | --- | --- |
| `/login` | `onLogin(email, password)` | Navigate into the panel at `/`. |
| `/register` | `onRegister(name, email, password)` | Navigate into the panel at `/`. |
| `/recover` | `onRecover(email)` | Return to `/login` (the reset email went out). |
| `/lock` | `onUnlock(password)` | Navigate back into the panel at `/`. |

A `null` callback is treated as an automatic success, which is what keeps the demo a
one-liner. The auth screens are mounted outside the shell, so they render full-page
with no sidebar.

## Idle-lock

Set `idleLockTimeout` and the panel locks itself after that much inactivity inside
the shell. Leave it null and the panel never auto-locks.

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

Both pointer activity and keyboard activity reset the countdown, so typing a long
form does not lock the panel mid-keystroke. When the timer fires, Beak navigates to
`/lock`.

The `/lock` route is mounted whenever `auth` is set, timeout or not, so you can send
a user there yourself (a "lock now" button, for instance). The lock screen shows
`lockUserName` (falling back to the panel title) and validates the entered password
through `onUnlock`.

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
    - `idleLockTimeout: const Duration(minutes: 10)` locks after ten idle minutes.
    - `onUnlock` returning `true` sends the user back to `/`. A `null` `onUnlock`
      accepts any password, which is demo-friendly but not something you ship.
    - Locking is a client convenience, not a security boundary. The data behind the
      lock screen is only as safe as the backend policy guarding it.

## Reference

`BeakAuthConfig` fields and defaults:

| Field | Type | Default | Purpose |
| --- | --- | --- | --- |
| `register` | `bool` | `true` | Whether `/register` is mounted. |
| `recover` | `bool` | `true` | Whether `/recover` is mounted. |
| `onLogin` | `Future<bool> Function(String, String)?` | `null` | Validates a sign-in. |
| `onRegister` | `Future<bool> Function(String, String, String)?` | `null` | Handles a registration. |
| `onRecover` | `Future<bool> Function(String)?` | `null` | Handles a recovery request. |
| `idleLockTimeout` | `Duration?` | `null` | Inactivity before auto-lock; null disables it. |
| `lockUserName` | `String?` | `null` | Name on the lock screen; falls back to the title. |
| `onUnlock` | `Future<bool> Function(String)?` | `null` | Validates the unlock password. |

## Continue reading

- [Maintenance and coming soon](maintenance-and-coming-soon.md) the other pair of config-mounted, outside-the-shell routes.
- [The navigation shell](the-navigation-shell.md) the shell the auth screens sit outside of, and where idle-lock counts inactivity.
- [Auth and policies](../backend/auth-and-policies.md) the server-side guard that makes client auth mean something.
- [Configuration options](../reference/configuration-options.md) every `BeakPanelConfig` field in one table.
