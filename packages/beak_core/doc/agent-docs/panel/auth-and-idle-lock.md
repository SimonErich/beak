# Auth and idle-lock

> Put a sign-in in front of the panel, choose who owns the session, and lock the shell after inactivity. Routes, redirects and the limits of each.

A new panel has no sign-in. A `/login` route exists, and nothing sends anyone to it. After this page you can put the panel behind a session, decide whether Beak's HTTP store or your own adapter owns that session, and lock the shell after a stretch of inactivity.

Auth has two halves, and this page is the panel's. The server decides who may sign in and what each account may do. The panel signs in, keeps the session and sends it with every request. Hiding a button is not protection: a client that skips the panel skips the check too, so the rules live in the server's [policies](../backend/auth-and-policies.md).

## At a glance

| | |
| --- | --- |
| Switched on by | `auth:` on `BeakPanel` or `BeakPanelConfig`. Generated panel: `lib/auth.dart`, written by `beak eject auth` |
| Left out | No gate and no redirect. A `/login` route is still mounted, and nothing sends anyone to it |
| Default session | `BeakSessionStore`: `POST /api/auth/login`, then a bearer token held in memory |
| Your own backend | `BeakAuthConfig(adapter: ...)` with a `BeakAuthAdapter` |
| Routes | `/login`, `/register` and `/recover` (both opt in), `/lock`. All outside the shell |
| Idle lock | `idleLockTimeout` and `onUnlock`, both on `BeakAuthConfig` |
| Enforces access | No. The server does |

## Switch it on

Start with the server, because a panel with `auth:` in front of a server without accounts is a login form nobody can pass. `BeakAuthSessions` holds the store sessions live in, the accounts that may sign in and the secret that hashes their passwords:

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
final class BeakAuthSessions {
  /// Creates the auth-surface configuration.
  const BeakAuthSessions({
    required this.store,
    required this.users,
    required this.secret,
  });

  /// Where sessions live.
  final TokenSessionStore store;

  /// The accounts that may log in.
  final List<BeakUserAccount> users;

  /// The secret behind [hashBeakPassword].
  final String secret;
}
```

Hand it to `BeakServer(authSessions: ...)`. In a generated project that is `defaults.build(authSessions: ...)` in `lib/server.dart`, see [Running the server](../backend/running-the-server.md). The server then mounts `POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`, and turns the bearer token on every other request into a principal. That only names the caller. What the caller may do is the server's policy, and `BeakServer` allows everything until you give it one: [Auth and policies](../backend/auth-and-policies.md).

Now the panel. The generated panel and the authored panel both take the same `BeakAuthConfig`:

**Generated panel**

```console
$ beak eject auth
  created lib/auth.dart

  run `beak prepare` to wire it up
```

The file returns Beak's default, so it compiles and changes nothing until your first edit:

```dart title="lib/auth.dart"
import 'package:beak/panel.dart';

/// Which auth routes the panel mounts, and what they call.
///
/// The default adapter uses the server's generated `/api/auth/login`.
/// Supply a BeakAuthAdapter for another backend. Registration and password
/// recovery stay disabled unless both configured and supported by the adapter.
BeakAuthConfig beakAuth() => const BeakAuthConfig();
```

`beak prepare` finds `beakAuth()` and writes `auth: auth.beakAuth()` into `lib/beak/panel.g.dart`. Only the function name matters, the file may hold more.

**Authored panel**

`BeakPanel` takes `auth:` directly. Illustrative, with the real constructor:

```dart
BeakPanel(
  title: 'Shop',
  resources: [ProductResource()],
  auth: const BeakAuthConfig(),
)
```

That is all the panel needs. The default store does the rest:

> **Note: What just happened**
>
> - The store starts as a guest, so the router sends the first request to `/login`.
> - The form posts `username` and `password` to `/api/auth/login`. The server answers with a `token` and the `principal` (`id`, `roles`).
> - `BeakSessionStore` keeps that `BeakSession` in memory, and the client adds `Authorization: Bearer <token>` to every request from then on.
> - The state change reaches the router, and the redirect below moves the visitor to `/`.

> **Question: What this skipped**
>
> - Who may read or write which table is the server's [policy](../backend/auth-and-policies.md), not the panel's.
> - Your own user system, or Serverpod, replaces the store with an adapter, see [Bring your own backend](#bring-your-own-backend).

## What a visitor sees

`BeakAuthRouterRefresh` watches the adapter's state and decides every navigation. The whole rule set:

```dart title="packages/beak_frontend/lib/src/auth/beak_auth_gate.dart"
String? redirect(String path) {
  final authPath = const {'/login', '/register', '/recover'}.contains(path);
  final publicPath =
      authPath ||
      const {'/500', '/maintenance', '/coming-soon'}.contains(path);
  return switch (adapter.state.value) {
    BeakAuthGuest() when !publicPath => '/login',
    BeakAuthAuthenticated(:final identity)
        when !identity.canAccessPanel && !publicPath && path != '/403' =>
      '/403',
    BeakAuthAuthenticated(:final identity)
        when identity.canAccessPanel && authPath =>
      '/',
    _ => null,
  };
}
```

| State | Where | What happens |
| --- | --- | --- |
| Guest | Any path except `/login`, `/register`, `/recover`, `/500`, `/maintenance`, `/coming-soon` | Redirect to `/login` |
| Signed in, `canAccessPanel: false` | Any path except those and `/403` | Redirect to `/403` |
| Signed in with access | `/login`, `/register`, `/recover` | Redirect to `/` |
| Loading or failed | Anywhere | Stay on the URL. `BeakAuthGate` shows a loading label, or a card with Retry and Back to sign in. Protected content stays unmounted |

There is no return URL. A guest who opens `/orders/42` lands on `/login`, and after signing in lands on `/`: the screen mounted there, your `home:`, or the first destination. The panel forgets the page you came for.

The auth routes sit outside the shell and outside the gate. That keeps the form mounted while the state flips from guest to signed in, and it is why they render full page without a sidebar:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
List<RouteBase> beakAuthRoutes(BeakPanelConfig config) {
  final auth = config.auth ?? const BeakAuthConfig();
  GoRoute route(String path, BeakAuthMode mode) => GoRoute(
    path: path,
    builder: (context, state) => BeakAuthPage(
      key: ValueKey(mode),
      title: config.title,
      config: auth,
      mode: mode,
      onSignedIn: () => context.go(mode == BeakAuthMode.login ? '/' : '/login'),
      onModeChanged: (next) => context.go(switch (next) {
        BeakAuthMode.login => '/login',
        BeakAuthMode.register => '/register',
        BeakAuthMode.recover => '/recover',
      }),
    ),
  );
  return [
    route('/login', BeakAuthMode.login),
    if (auth.allowsRegistration) route('/register', BeakAuthMode.register),
    if (auth.allowsRecovery) route('/recover', BeakAuthMode.recover),
    GoRoute(
      path: '/lock',
      builder: (context, state) => OiAuthPage.lock(
        label: config.title,
        userName: auth.lockUserName ?? config.title,
        onUnlock: (password) async {
          final unlocked =
              await (auth.onUnlock?.call(password) ??
                  Future<bool>.value(false));
          if (unlocked && context.mounted) context.go('/');
          return unlocked;
        },
      ),
    ),
  ];
}
```

`/login` is always there. `/register` and `/recover` need two things at once: `register: true` (or `recover: true`) on the config, and an adapter that supplies the matching flow. The default store supplies neither, so `register: true` or `recover: true` without an `adapter` throws a `BeakConfigurationException` when the panel starts. An adapter that lacks the flow leaves the route unmounted, and the address bar shows the not-found page. When a flow completes the page returns to `/login`. An adapter that signs the new account in moves on to `/` through the second row above.

Sign-in screens follow the panel locale. English and German ship with Beak.

## Sign out and switching accounts

With `auth:` set and no `shellActions`, the top bar carries `BeakLogoutButton`. Once you set `shellActions` the panel drops that button, because the top bar is yours, so you place it yourself: `BeakLogoutButton(adapter: ...)` takes the same adapter, and `beakDependencies(context)<BeakSessionStore>()` is the default one.

The default store clears its local session first, then asks the server to revoke the token. If the revocation fails, the visitor is signed out locally either way, and the token stays valid on the server until it expires.

Switching accounts is safe by construction. The shell is keyed by the identity id, so a different account gets a fresh tree and the previous account's open forms and drafts are disposed. The same account refreshing its permissions keeps its tree and its drafts.

## Bring your own backend

An adapter replaces the HTTP store when the session lives somewhere else: your own user service, an SSO library, Serverpod. It is the error boundary for authentication, so its operations return `BeakResult` and never throw transport exceptions into a widget:

```dart title="packages/beak_frontend/lib/src/auth/beak_auth_adapter.dart"
abstract class BeakAuthAdapter {
  /// Live state consumed by the router and authentication initialization gate.
  ReadonlySignal<BeakAuthState> get state;

  /// Signs in and resolves application permissions before reporting success.
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  });

  /// Clears the device session even if remote revocation is unavailable.
  Future<BeakResult<void>> logout();

  /// Re-resolves permissions without unmounting an already ready screen.
  Future<BeakResult<void>> refresh();

  /// Optional factory for a new, independently owned registration flow.
  BeakEmailVerificationFlow Function()? get registration => null;

  /// Optional factory for a new, independently owned password recovery flow.
  BeakEmailVerificationFlow Function()? get recovery => null;
}
```

The state it publishes is the sealed `BeakAuthState`: `BeakAuthLoading`, `BeakAuthGuest`, `BeakAuthAuthenticated(identity)` and `BeakAuthFailure(error)`. The identity is `BeakAuthIdentity(id:, displayName:, canAccessPanel:)`. Set `canAccessPanel` from your own permission rules, but prefer refusing the login outright: an account with `false` is parked on `/403`, where the page offers `Back to sign in`, which ends the session.

Registration and recovery are the same three-step flow (email, code, new password), each step a call on a `BeakEmailVerificationFlow`: `start(email:)`, `verify(code:)`, `complete(password:)`. The adapter's `registration` and `recovery` getters return a factory, so every mounted form owns a fresh flow and releases it in `dispose()`.

With an adapter, Beak registers no `BeakClient` and no `BeakSessionStore`. That has a price: every model must be bound to a data source of its own, or you pass one as `dataSource:`. Otherwise registration throws `External authentication requires bound models or a data source.` at startup.

### Serverpod

Inside a Serverpod workspace, Serverpod owns the session and Beak's screens sit on top. `ServerpodAuthAdapter` is the `BeakAuthAdapter`, and `serverpodBeakDataSource(dispatch)` is the data source, so Beak makes no HTTP requests of its own and sends no bearer token. The identity resolver is where `canAccessPanel` gets decided, from the token's scopes, and `beak.admin` is the scope that opens the panel:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
/// Maps the signed-in Serverpod user to Beak's identity: only an account
/// holding [beakAdminScopeName] may open the panel.
///
/// The scopes come from the token Serverpod issued at sign-in, so a grant
/// takes effect on the next sign-in. The server's endpoint gate and Beak's
/// policy still decide every request; this only keeps a signed-in customer on
/// the sign-in screen instead of an empty shell of 403s.
ServerpodIdentityResolver bookshopAdminIdentity(
  FlutterAuthSessionManager sessionManager,
) => (signedIn) async {
  final AuthSuccess? auth = sessionManager.authInfo;
  if (!signedIn || auth == null) return null;
  return BeakAuthIdentity(
    id: auth.authUserId,
    canAccessPanel: auth.scopeNames.contains(beakAdminScopeName),
  );
};
```

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
/// The Dog-Eared Books admin: Beak's panel over the Serverpod tunnel.
///
/// [dispatch] is the generated `client.beakAdmin.dispatch` (a fake in the
/// widget tests); [auth] is the [ServerpodAuthAdapter] over the same client.
/// Sign-up and password recovery use Serverpod's email IDP; a new account
/// still needs the admin scopes granted (`bin/beak_admin.dart grant`) before
/// it can open the panel.
BeakPanel bookshopAdminPanel({
  required BeakTunnelDispatch dispatch,
  required BeakAuthAdapter auth,
}) => BeakPanel(
  title: 'Dog-Eared Books',
  resources: bookshopResources(),
  auth: BeakAuthConfig(adapter: auth, register: true, recover: true),
  dataSource: serverpodBeakDataSource(dispatch),
);
```

Grants, revokes and how long a revoked admin keeps working are on [Authentication and scopes](../serverpod/authentication.md).

## Idle lock

Set `idleLockTimeout` and the panel locks itself after that long without input. Leave it `null` and it never does. The lock needs an `auth:` config, because the timer is read from it:

```dart title="packages/beak_frontend/test/src/panel/beak_screen_routing_test.dart"
auth: BeakAuthConfig(
  adapter: _TestAuth(signedIn: true),
  idleLockTimeout: const Duration(seconds: 1),
  lockUserName: 'Aisha',
),
```

The timer covers every routed page, a full-screen form included. Pointer down, pointer move, scroll and any key press reset it, so typing a long form does not lock the panel mid-sentence. When it fires, the router goes to `/lock`:

```dart title="packages/beak_frontend/lib/src/panel/beak_router.dart"
class _BeakIdleLock extends HookWidget {
  const _BeakIdleLock({required this.timeout, required this.child});

  final Duration timeout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final reset = useRef<VoidCallback>(() {});

    useEffect(() {
      Timer? timer;
      void schedule() {
        timer?.cancel();
        _lockingRouters.remove(router);
        timer = Timer(timeout, () {
          _lockingRouters.add(router);
          router.go('/lock');
        });
      }

      // Keyboard events travel the focus pipeline, not the pointer pipeline
      // — without this hook, typing continuously in a form still locks the
      // panel mid-keystroke and destroys the unsaved input.
      bool onKey(KeyEvent event) {
        schedule();
        return false;
      }

      reset.value = schedule;
      schedule();
      HardwareKeyboard.instance.addHandler(onKey);
      return () {
        HardwareKeyboard.instance.removeHandler(onKey);
        timer?.cancel();
        _lockingRouters.remove(router);
      };
    }, [timeout, router]);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => reset.value(),
      onPointerMove: (_) => reset.value(),
      onPointerSignal: (_) => reset.value(),
      child: child,
    );
  }
}
```

`/lock` shows the obers_ui lock screen with `lockUserName` (default: the panel title) and a password field. Whatever the visitor types goes to `onUnlock`, and a `true` answer sends them to `/`. Beak ships no default check: an absent `onUnlock` rejects every password. What to verify is up to you, usually the password against your backend. Illustrative, with a stand-in for that check:

```dart
BeakAuthConfig beakAuth() => BeakAuthConfig(
  idleLockTimeout: const Duration(minutes: 10),
  lockUserName: 'Aisha',
  onUnlock: (password) async => password == 'let-me-in',
);
```

The lock is a curtain, not a door. It hides the panel from someone walking past. It does not end the session: the token stays in memory and stays valid on the server until it expires or the user signs out. Three details follow from how it is built:

- A form with unsaved changes does not hold the lock back. The lock is a navigation, but it skips the "Leave this form?" question, because nobody is there to answer it. What was typed is kept only if the screen has a `drafts:` store; without one, the unsaved input is gone when the person unlocks.
- Unlocking lands on `/`, not on the page that was open.
- A wrong password shows obers_ui's own message, `Operation failed. Please try again.`, in English.

## Inside a host router

`BeakPanel` is a thin wrapper. It registers the dependencies, builds a `BeakAuthRouterRefresh` from the adapter (or the default store), and hands both to `createBeakRouter`:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel.dart"
final routing = useMemoized(() {
  final container = GetIt.asNewInstance();
  registerBeakDependencies(
    locator: container,
    config: config,
    dataSource: dataSource,
    httpClient: httpClient,
  );
  final authRefresh = config.auth == null
      ? null
      : BeakAuthRouterRefresh(
          config.auth?.adapter ?? container<BeakSessionStore>(),
        );
  return (
    container: container,
    router: createBeakRouter(config, authRefresh: authRefresh),
    authRefresh: authRefresh,
  );
  // The seams are part of the key: swapping a fake on rebuild used to
  // keep the previous one registered, so a test could not change source
  // mid-flight and never learned it had not.
}, [config, dataSource, httpClient]);
```

An app that already has a `GoRouter` assembles the same pieces itself: `registerBeakDependencies(config: ...)`, then `beakPanelRoutes(config)` for the shell and `beakAuthRoutes(config)` for the sign-in screens inside its own route list. To reuse Beak's redirect, give the router `refreshListenable: refresh` and `redirect: (_, state) => refresh.redirect(state.uri.path)`. If the host owns sign-in completely, skip `beakAuthRoutes`, pass `externalAuthentication: true` to `registerBeakDependencies`, and guard the shell with your own redirect. [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md) walks through that mount.

## Rules and limits

| Rule | What it means |
| --- | --- |
| No `auth:`, no gate | Without a config the panel renders for everyone. Nothing redirects to `/login`, and no idle timer runs |
| Sessions without a policy protect nothing | `authSessions` names the caller. `BeakServer` still defaults to allow-all until you pass a `policy` |
| The panel is not the boundary | A guest who reaches a page sees an empty shell at worst. The API refuses the data. Write the rules as [policies](../backend/auth-and-policies.md) |
| The default session lives in memory | Reloading the page signs the user out. The panel never calls `GET /api/auth/me` and stores no token |
| The default session expires on the server | `InMemoryTokenSessionStore` keeps a session for 12 hours from creation by default, and forgets all of them on restart. A request the server answers with 401 ends the session in the panel: it signs the user out and lands on `/login`. The API keeps its rules, so signing in again starts a fresh session |
| The sign-in field is a username or email | `BeakAuthViewModel.login` trims the identifier and only requires it to be non-empty, so a `BeakUserAccount` named `admin` signs in. Registration and recovery still check the address with `BeakEmail`, because they send a code to it |
| `canAccessPanel: false` parks the account on `/403` | The page offers `Back to sign in` for such an account, which ends its session, because `Back to dashboard` would redirect to `/403` again. Refuse such logins in the adapter when you can, as `ServerpodAuthAdapter` does |
| Register and recover need both switches | Config flag and adapter capability. Asking for either without an `adapter` throws at startup, because the default store has neither flow. An adapter that lacks the flow means no route and the not-found page, not a disabled button |
| Deep links are not remembered | Sign-in always ends on `/` |
| The lock is a UI lock | Token and server session stay valid. It covers every routed page and is not held back by a form with unsaved changes, see above |
| `shellActions` removes the sign-out button | Add `BeakLogoutButton` yourself |
| One session authority | An adapter owns the session state. Do not copy its credentials into another Beak store |

## Verify it

The repo's tests cover the routes, the gate, the redirect and the lock. From `packages/beak_frontend`:

```console
$ flutter test test/src/auth test/src/panel/beak_screen_routing_test.dart test/src/panel/beak_idle_lock_test.dart
00:00 +19: a 401 from the API signs the panel out
00:02 +36: auth routes login always mounts; register/recover follow config
00:02 +37: auth routes register is absent when disabled
00:02 +43: idle lock the lock route renders the lock screen
00:02 +44: idle lock the panel auto-locks after the idle timeout
00:02 +45: All tests passed!
```

The generated path, in a scratch project made with `beak create demo --no-pub --beak-path <repo>`, after `beak eject auth` and `beak prepare`:

```console
$ beak prepare
1 model · 0 resource classes · 0 screens · 1 override
$ grep -n "auth" lib/beak/panel.g.dart
8:import '../auth.dart' as auth;
23:    auth: auth.beakAuth(),
```

Three behaviours have a test of their own. `test/src/auth/unauthorized_test.dart` drives the default store through a mocked HTTP client, with `auth: const BeakAuthConfig()` and no adapter: the person signs in as `admin`, the first query is answered 401, and the panel sends `POST /api/auth/logout` and ends on the sign-in page. `test/src/panel/beak_idle_lock_test.dart` uses a signed-in fake adapter, a one-second timeout and the default note resource:

```console
$ flutter test test/src/panel/beak_idle_lock_test.dart
00:00 +1: an idle list locks the panel
00:00 +2: a form with unsaved changes does not hold the lock back
00:01 +3: a full-screen form locks too
00:01 +4: activity keeps a full-screen form open
00:01 +4: All tests passed!
```

The second line is a normal create form with typed text: the router reaches `/lock` and no "Leave this form?" dialog opens. The third is a `fullScreen: true` create form left alone for two seconds.

## Reference

Import `package:beak/panel.dart`. The server types are in `package:beak/server.dart`.

```dart title="packages/beak_frontend/lib/src/panel/beak_auth_config.dart"
const BeakAuthConfig({
  this.adapter,
  this.register = false,
  this.recover = false,
  this.idleLockTimeout,
  this.lockUserName,
  this.onUnlock,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `adapter` | `BeakAuthAdapter?` | `null` | Session authority. `null` uses the registered `BeakSessionStore` over HTTP |
| `register` | `bool` | `false` | Opt in to the adapter's registration flow |
| `recover` | `bool` | `false` | Opt in to the adapter's password recovery flow |
| `idleLockTimeout` | `Duration?` | `null` | Inactivity before the router goes to `/lock`. `null` never locks |
| `lockUserName` | `String?` | panel title | Name on the lock screen |
| `onUnlock` | `Future<bool> Function(String password)?` | `null` | Checks the unlock password. `null` rejects every password |

`allowsRegistration` is `register && adapter?.registration != null`, and `allowsRecovery` is the same with `recover` and `recovery`.

| Symbol | Kind | What it is |
| --- | --- | --- |
| `BeakSessionStore` | class | Default adapter. `state`, `session`, `token`, `isSignedIn`, `signIn`, `login`, `logout`, `signOut`. `refresh` does nothing |
| `BeakAuthState` | sealed class | `BeakAuthLoading`, `BeakAuthGuest`, `BeakAuthAuthenticated`, `BeakAuthFailure` |
| `BeakAuthIdentity` | class | `id`, `displayName`, `canAccessPanel` (default `true`) |
| `BeakEmailVerificationFlow` | interface | `start`, `verify`, `complete`, `dispose` |
| `BeakAuthGate` | widget | Renders its child only for a signed-in account with access |
| `BeakAuthRouterRefresh` | `ChangeNotifier` | `redirect(String path)` and the refresh signal for a `GoRouter` |
| `BeakAuthPage`, `BeakAuthMode` | widget, enum | The sign-in, registration and recovery screens; `login`, `register`, `recover` |
| `BeakLogoutButton` | widget | Sign-out button for an adapter |
| `beakAuthRoutes`, `beakPanelRoutes`, `createBeakRouter` | functions | Routes for a host router, and the full router |
| `registerBeakDependencies` | function | Registers the client, session store and data source. `externalAuthentication: true` skips the first two |
| `BeakAuthSessions`, `BeakUserAccount`, `hashBeakPassword` | server | Accounts, and the password hash under a secret |
| `TokenSessionStore`, `InMemoryTokenSessionStore` | server | Where sessions live; the in-memory one takes a `sessionTtl` |

## Continue reading

- [Maintenance and coming soon](maintenance-and-coming-soon.md): the two pages a guest can reach without signing in.
- [Auth and policies](../backend/auth-and-policies.md): what a signed-in account may read and write, decided on the server.
- [Authentication and scopes](../serverpod/authentication.md): the same screens over Serverpod's sessions.
- [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md): mounting the panel routes in a router you own.
