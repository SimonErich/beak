# beak_serverpod_flutter

The Flutter side of Beak on Serverpod 4: Beak's login, registration and
password-recovery screens over Serverpod's email sign-in, and, for the admin app,
the client that carries every panel request through one Serverpod endpoint call.
Serverpod keeps the credentials, the secure storage and the token refresh. This
package only adapts them.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## Which parts you need

| Part | Admin app | Client bridge | What it does |
| --- | --- | --- | --- |
| `ServerpodAuthAdapter` | yes | yes | Gives Beak's sign-in screens a Serverpod session. |
| `serverpodBeakDataSource`, `ServerpodBeakHttpClient` | yes | no | Runs the panel's HTTP data layer over `client.<endpoint>.dispatch`. |

The admin app path also needs
[`beak_serverpod_server`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_server)
on the server. The bridge path needs
[`beak_serverpod`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod)
and, to write its resources,
[`beak_serverpod_generator`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_generator).
[Choosing an integration](https://simonerich.github.io/beak/serverpod/choosing-an-integration/)
says which path fits.

## Versions

| Part | Version |
| --- | --- |
| `serverpod_auth_core_flutter`, `serverpod_auth_idp_client`, `serverpod_client` | `>=4.0.3 <5.0.0` declared, 4.0.3 tested |
| Flutter | `>=3.41.0` declared. Serverpod 4.0.3 itself needs Dart 3.12.2 and Flutter 3.44.4 |

Earlier Beak builds pinned `4.0.0-beta.0`, and this package does not resolve
against it. Between the beta and 4.0.x, `ServerpodClientException` became sealed
and lost its `statusCode`: the status lives on `ServerpodClientHttpException`.
Code that caught `ServerpodClientException` and read `statusCode` has to catch
`ServerpodClientHttpException` instead. The adapter and the tunnel already do.
[Version compatibility](https://simonerich.github.io/beak/serverpod/versions/)
has the whole table.

## Sign-in

[Authentication and scopes](https://simonerich.github.io/beak/serverpod/authentication/)
follows a sign-in from the adapter to the first request: who may pass each door,
how to grant and revoke panel access, and how long a revoked admin keeps
working.

Build the adapter in `main`, after the client has restored its stored session,
and call `initialize()` before `runApp`:

```dart title="examples/serverpod/bookshop_admin/lib/main.dart"
/// The bookshop admin: Serverpod's email login through Beak's auth screens,
/// and every panel request tunnelled through the generated
/// `client.beakAdmin.dispatch`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionManager = FlutterAuthSessionManager();
  final Client client =
      Client(
          await getServerUrl(),
          // Buffered CSV export rides the tunnel too; the 20 second default
          // is for ordinary calls.
          connectionTimeout: const Duration(seconds: 60),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = sessionManager;
  // Restores the stored session and refreshes its access token if needed.
  await client.auth.initialize();
  final auth = ServerpodAuthAdapter(
    client: client,
    sessionManager: sessionManager,
    resolveIdentity: bookshopAdminIdentity(sessionManager),
  );
  await auth.initialize();
  runApp(bookshopAdminPanel(dispatch: client.beakAdmin.dispatch, auth: auth));
}
```

`resolveIdentity` is where the app decides who may open the panel. Return `null`
for a guest, or a `BeakAuthIdentity` whose `canAccessPanel` comes from the
scopes of the token Serverpod issued:

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

That check is convenience. The endpoint gate and the policy on the server decide
every request, so a client that skips it gets nothing.

Registration and recovery are off until you opt in, and each also needs the
adapter to support it. The tunnel data source goes in as `dataSource:`:

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

Pass the source as `dataSource:`, not `httpClient:`. With an external
authentication adapter the panel registers no `BeakClient` of its own, so it
ignores `httpClient:` and requires a data source. The client sends no bearer
token: the Serverpod client authenticates the `dispatch` call itself.

## The tunnel client

`serverpodBeakDataSource(dispatch)` is Beak's stock `HttpBeakDataSource` and
`BeakClient` over a `ServerpodBeakHttpClient`. The URL's host is a placeholder
(`beakServerpodTunnelOrigin`); only the path and query travel.

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_beak_data_source.dart"
HttpBeakDataSource serverpodBeakDataSource(BeakTunnelDispatch dispatch) =>
    HttpBeakDataSource(
      BeakClient(
        baseUrl: beakServerpodTunnelOrigin,
        httpClient: ServerpodBeakHttpClient(dispatch),
      ),
    );
```

`serverpodTunnelFault` classifies Serverpod's sealed client exceptions:

| Serverpod throws | The panel sees |
| --- | --- |
| `ServerpodClientUnauthorized` | 401, "Your session has ended. Sign in again." |
| `ServerpodClientForbidden` | 403, "This account may not use the admin." |
| `ServerpodClientHttpException` with 413 | 413, the request is larger than the server accepts |
| Any other `ServerpodClientHttpException` | Its own status and message |
| `ServerpodClientNetworkException` | An `http.ClientException`, as a socket failure would be |
| `ServerpodClientUnknownException` | 502 |
| Anything else, such as your own serialized exception | Propagates unchanged |

`package:beak_serverpod_flutter/tunnel.dart` exports the client and the wire
types without Flutter, for Dart VM tools and tests.

## What the adapter does

- The email flows use the generated email identity provider endpoint: `login`,
  `startRegistration`, `verifyRegistrationCode`, `finishRegistration`,
  `startPasswordReset`, `verifyPasswordResetCode` and `finishPasswordReset`.
  Finishing a password reset returns to the sign-in screen and does not mint a
  session.
- A sign-in whose resolved identity has `canAccessPanel: false` is signed out
  again and reported as `The account cannot access this panel.`
- It ignores superseded account resolutions, keeps ready screens mounted while it
  refreshes permissions, and clears a rejected stored session on HTTP 401 or when
  the `isUnauthenticated` callback recognizes your own error.
- Credential writes are ordered, so a logout that starts while a login is still
  persisting wins. Local logout stays effective when remote revocation fails.
- `exceptionMapper` (a `ServerpodAuthExceptionMapper`) maps your own serialized
  exceptions. Unknown transport failures become a
  `BeakConfigurationException("Authentication transport failed.")`.
- For a host router, `BeakAuthRouterRefresh`, `beakAuthRoutes` and
  `beakPanelRoutes` (from `beak_frontend`) mount Beak's gates, screens and logout.

## Main types

| Type | What it is |
| --- | --- |
| `ServerpodAuthAdapter` | A `BeakAuthAdapter` over a generated client and a `FlutterAuthSessionManager`. Call `initialize()` once, `dispose()` with the owner. |
| `ServerpodIdentityResolver` | `Future<BeakAuthIdentity?> Function(bool signedIn)`: your projection of the account into the panel. |
| `ServerpodAuthExceptionMapper` | Maps your domain exceptions to `BeakException`. |
| `serverpodBeakDataSource` | The panel's data source over `client.<endpoint>.dispatch`. |
| `ServerpodBeakHttpClient` | An `http.Client` over the one string call. |
| `serverpodTunnelFault` | The classifier in the table above. |
| `beakServerpodTunnelOrigin` | The placeholder origin (`http://beak.tunnel`). |

## Limits

- Only the email identity provider with JWT tokens is tested. The example has no
  cookie mode, no server-side sessions and no other provider.
- Public registration never grants panel access. A new account holds no scope
  until the server side grants `beak.admin`, and a grant takes effect on the next
  sign-in.
- Every panel call is a Serverpod call, so the server's `maxRequestSize` caps it
  (512 KiB in the template) and the client's `connectionTimeout` applies. A CSV
  export is buffered and rides the tunnel too.
- Beak's constraints allow any 4.x from 4.0.3. Only 4.0.3 is tested, and the
  matching pins in the client, server and app are yours to keep.

## Continue reading

- [Authentication and scopes](https://simonerich.github.io/beak/serverpod/authentication/): the gate, the scope, grants and revokes, and how long a revoke takes.
- [Setting up the admin app](https://simonerich.github.io/beak/serverpod/admin-app/setup/): the whole path, file by file.
- [Version compatibility](https://simonerich.github.io/beak/serverpod/versions/): pins, floors and the 4.0 beta break.
- [Auth and idle-lock](https://simonerich.github.io/beak/panel/auth-and-idle-lock/): the panel side of authentication.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md), including a section, "Migrating from beak_serverpod 0.0.x". Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
