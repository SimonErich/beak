# beak_serverpod_flutter

Beak-owned login, registration and password recovery over an existing Serverpod
4.0.0-beta.0 generated client and FlutterAuthSessionManager. Serverpod retains
credential storage/token refresh; the app supplies account/permission projection.

```dart
final auth = ServerpodAuthAdapter(
  client: client,
  sessionManager: sessionManager,
  resolveIdentity: (signedIn) async {
    if (!signedIn) return null;
    return loadPanelIdentity();
  },
  exceptionMapper: mapDomainException,
  isUnauthenticated: isDomainUnauthenticated,
);
await auth.initialize();
final config = BeakAuthConfig(adapter: auth, recover: true);
```

`loadPanelIdentity` returns a BeakAuthIdentity (or typed subclass) with the actual
server-derived panel access decision. No application state should be mutated
until the identity appears in the adapter's committed state. Initialize after
secure session storage and host dependencies are ready; dispose with the owner.

Registration/recovery require explicit BeakAuthConfig opt-in. The adapter's
email-code-password flows use the generated email IDP endpoint. Reset completion
returns to login without automatically minting a session. Configure verification
email delivery on the server. Public registration never grants panel permission.

The adapter ignores superseded account resolutions, keeps ready screens mounted
while refreshing permissions, and clears rejected stored sessions on HTTP 401 or
host-recognized unauthenticated errors. Local logout remains effective when
remote revocation fails. Backend checks remain authoritative.
Credential mutations are serialized so logout also wins over a login already
waiting for secure storage, without publishing the intermediate stale identity.

For host-router integration use `BeakAuthRouterRefresh`, `beakAuthRoutes` and
`beakPanelRoutes`; Beak owns the corresponding gates, screens and logout action.
See [the auth guide](../../docs/panel/auth-and-idle-lock.md).

Run `flutter test` and `dart analyze` in this package. Tests inject generated
endpoint/session fakes and exercise auth/permission races and all email steps.
