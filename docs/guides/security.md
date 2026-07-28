---
title: Security
description: The security seams of a Beak backend: authentication guards, per-resource policies, row scopes, the password secret, upload validation, storage-key hardening, and CORS.
---

# Security

After this page you can lock down a Beak backend: authenticate requests, gate
every generated endpoint by role, narrow which rows a principal sees, keep the
password secret out of source, and trust that uploads and storage keys cannot be
used to write where they should not.

Beak generates the whole CRUD surface for you, which means it also generates the
whole attack surface for you. The defaults are deliberately open (a fresh panel
works with no auth at all) so you configure security on purpose, not by
accident. This page walks the seams in the order you should close them.

## Where security is configured

One file: `lib/server.dart`. It declares a `beakServer` function that receives
everything Beak resolved and returns the server to run. `beak eject server`
writes the starter, which returns the default unchanged.

```dart title="examples/store/lib/server.dart"
/// Builds the store's server on top of everything Beak resolved.
///
/// [defaults] already carries the database connection, the model registry and
/// the upload driver; this adds the two things a real store needs and Beak
/// cannot guess: who may log in, and which rows each of them sees.
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
        // ... a second account, for a customer ...
      ],
    ),
    authGuard: TokenSessionAuthGuard(store),
  );
}
```

Three pieces share one store: the sessions the login endpoint mints into, the
guard that reads them back, and the policy that judges the resulting principal.
The `authSessions` store and the `authGuard`'s store must be the same instance,
or a freshly minted token will not be recognised. That is why the store is a
local variable here and passed to both.

!!! warning "The panel is not the boundary"
    Hiding a resource in `beak.yaml`, or a button behind a role check in the UI,
    is presentation. The API is still there, and a client that skips the panel
    skips every UI-level check with it. Everything on this page runs in the
    backend, which is the only place a rule holds.

## Authentication: who is this request

Authentication in Beak is one interface, `BeakAuthGuard`. It resolves the
identity behind a request, and it is the pluggable seam the auth middleware
calls on every request.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
--8<-- "packages/beak_backend/lib/src/auth/beak_auth_guard.dart:BeakAuthGuard"
```

The contract has a sharp edge worth internalizing: `null` means anonymous (no
credentials at all), but credentials that are present and wrong must throw, not
return `null`.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
/// Implementations return `null` for anonymous requests (no credentials at
/// all) and throw a [BeakAuthenticationException] for credentials that are
/// present but invalid, so forged tokens never demote silently to
/// anonymous. Implement this to plug in an alternative scheme (JWT, an API
/// gateway header, …); [TokenSessionAuthGuard] is the built-in Bearer-token
/// implementation. Install it via [beakAuthMiddleware] or [BeakServer]'s
/// `authGuard` parameter:
/// ...
```

The built-in guard, `TokenSessionAuthGuard`, reads opaque `Bearer` tokens and
looks them up in a server-side session store. A missing header is anonymous; a
malformed or unknown token throws. Implement the interface yourself to plug in
another scheme (a JWT, an API-gateway header) and pass it as `authGuard`.

The store mints and revokes those tokens. The default keeps sessions in process
memory with a time-to-live; a deployment behind more than one instance wants a
shared, persistent `TokenSessionStore` (a table, Redis) so a login on one node
is recognised on the next.

!!! warning "In-memory sessions vanish on restart"
    `InMemoryTokenSessionStore` is right for local development and tests. In
    production it means every deploy logs everyone out, and it does not work at
    all across multiple instances. Implement `TokenSessionStore` over shared
    storage before you scale past one process.

## Authorization: what may this request do

Authentication answers "who"; a `BeakPolicy` answers "may they". Every generated
handler consults the policy before it acts, passing the resolved principal and
the target table (plus the record id or upload storage key for mutations).

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
abstract interface class BeakPolicy {
  /// Whether [principal] may read records of [table].
  bool canView(BeakPrincipal? principal, String table);

  /// Whether [principal] may create records of [table].
  bool canCreate(BeakPrincipal? principal, String table);

  /// Whether [principal] may update the record of [table] with [id].
  bool canUpdate(BeakPrincipal? principal, String table, Object id);

  /// Whether [principal] may delete the record of [table] with [id].
  bool canDelete(BeakPrincipal? principal, String table, Object id);
```

The default policy is `BeakAllowAllPolicy`: it permits everything. That is what
lets a brand-new panel work before you have written a line of auth, and it is
also why shipping without a real policy ships an open door. It is declared
`base` rather than `final` so a real policy can extend it and override only what
it restricts, which is usually two or three methods.

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
/// The default policy: everything is allowed — panels stay open until an
/// app configures a real policy.
///
/// Declared `base` rather than `final` so a real policy can extend it and
/// override only what it restricts. "Allow everything except deletes" is the
/// common shape, and spelling out five permissive methods to express it is
/// exactly the boilerplate that makes people skip writing a policy at all.
base class BeakAllowAllPolicy implements BeakPolicy {
```

A denial is translated to the right status by `enforcePolicyDecision`: an
anonymous request that is denied gets a 401 (sign in), an authenticated one gets
a 403 (not allowed). You never map those statuses yourself.

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
  if (principal == null) {
    throw BeakAuthenticationException('Sign in to $action "$table".');
  }
  throw BeakAuthorizationException(
    'Principal "${principal.id}" is not allowed to $action "$table".',
  );
```

Deleting an uploaded file has its own hook, `canDeleteUpload`, because a file is
identified by its storage key, not by a record id. Keep that logic separate from
`canDelete` so an upload-removal request can never smuggle a record id through
the record-delete gate.

## Row scopes: which rows may they touch

`canView` answers "may this principal read orders at all", which is not the same
question as "may this principal read *these* orders". Without a row scope, a
policy that intends "a customer sees only their own orders" is bypassed by
`POST /api/orders/query` with any filter the caller likes, because the filter
comes from the client.

Implement `BeakRowPolicy` instead of `BeakPolicy` and every read and write of the
table is intersected with `scopeFor`:

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
--8<-- "packages/beak_backend/lib/src/auth/beak_policy.dart:BeakRowPolicy"
```

Query, aggregate, get-one, update, delete, export and global search all apply it,
so there is no endpoint left to forget. The store's policy is three rules in
thirty lines:

```dart title="examples/store/lib/server.dart"
--8<-- "examples/store/lib/server.dart:StorePolicy"
```

!!! note "Refusing and narrowing are different answers"
    `canView` returning `false` is a refusal: 403 for a signed-in caller, 401
    for an anonymous one, and no data at all. A scope is not a refusal: the
    request succeeds, and the rows that are not theirs are not in the answer.
    Pick the refusal when the table is none of their business, and the scope
    when some of it is.

Note the column constants in the scope. A row policy is written against
`OrderColumns.customerId`, not the string `'customer_id'`, so renaming the field
in the schema class is a compile error here rather than a policy that silently
matches nothing.

## The password secret

Accounts never store plaintext. `hashBeakPassword` derives an HMAC-SHA256 hash
under a secret, and login recomputes the hash to compare.

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
/// Hashes [password] with HMAC-SHA256 under [secret] — what
/// [BeakUserAccount]s store instead of plaintext.
```

The same secret that hashed an account's password must be handed to
`BeakAuthSessions`, so login can recompute and compare. That secret is the one
value here you must keep out of source. Read it from `defaults.environment`,
which is the resolved environment (the real process environment, plus an
optional git-ignored `.env`), so a test that injects an environment injects it
into your auth configuration too.

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
  /// ```dart
  /// final secret = defaults.environment['AUTH_SECRET'] ?? 'dev-secret';
  /// ```
```

!!! danger "The secret lives in the environment, never in a commit"
    A literal fallback like the store's `'store-dev-secret'` is for local
    development only. Set the real value in the deployment's environment.
    Rotating the secret invalidates every stored hash, so treat it as long-lived
    and back it up.

## Upload validation

Every upload runs through `BeakUploadValidator` before a byte is stored. It
enforces the file rules from the field's `@Image` or `@FileField` annotation
(size, allowed MIME types and extensions, maximum dimensions, aspect ratio) and
returns a typed result you cannot ignore.

```dart title="packages/beak_core/lib/src/storage/beak_upload_validator.dart"
  BeakResult<BeakUpload> validate(
    BeakUpload upload, {
    int? maxSizeInBytes,
    List<BeakFileType> allowedTypes = const [],
    BeakDimensions? maxDimensions,
    double? aspectRatio,
    BeakDimensions? actualDimensions,
  }) {
```

Those rules are declared once, on the field, and enforced twice: in the browser
before the upload starts, and again in the API. A client that skips the panel
does not skip the check. Type checks look at both the MIME type and the file
extension, so a `.php` renamed to `.png` fails on one axis or the other. Failures
aggregate into a `BeakValidationException` keyed by `size`, `type`, `dimensions`,
and `aspectRatio`, which the handler maps to a 422 with per-aspect messages.

### Never trust the client's filename

The name the browser sends is display text, not a path. Beak mints the storage
key server-side from a fresh uuid plus the extension derived from the validated
MIME type; the client filename is never used to build a key.

```dart title="packages/beak_backend/lib/src/uploads/upload_service.dart"
  /// [generateKeyId] injects the storage-key mint for tests (defaults to
  /// uuid v4) — client filenames are never trusted for keys.
```

That single rule closes a whole class of attacks: a filename of
`../../etc/passwd` or `../../other-tenant/logo.png` cannot influence where the
bytes land, because the filename never reaches the key.

## Storage keys reject traversal

Even a key built internally is validated before it reaches a driver. Every
`BeakStorageDriver` shares one key builder, and its `validate` rejects anything
that could escape the storage root.

```dart title="packages/beak_core/lib/src/storage/beak_storage_key.dart"
  /// Validates [key]: non-empty, relative, `/`-separated, without empty,
  /// `.` or `..` segments and without backslashes.
  ///
  /// Throws a [BeakStorageException] describing the first violation.
  static void validate(String key) {
```

Absolute keys, backslashes, and `.` or `..` segments all throw. A path-traversal
attempt is a `BeakStorageException`, not a write outside the bucket.

## CORS

The backend attaches CORS headers on every response and answers `OPTIONS`
preflight with `204`. The middleware defaults to a permissive `*` origin:

```dart title="packages/beak_backend/lib/src/server/middleware/cors_middleware.dart"
Middleware beakCorsMiddleware({String allowedOrigin = '*'}) {
```

`*` is convenient in development, where the panel and the API run on different
ports. Two ways out in production:

- **Serve both from one origin.** Set `api.baseUrl: auto` in `beak.yaml` and the
  panel calls the origin it was served from, so no cross-origin request is made
  at all.
- **Name the origin.** Mount `BeakServer.handler` inside a pipeline of your own,
  with `beakCorsMiddleware(allowedOrigin: 'https://admin.example.com')` around
  it. The headers you set on the way out replace Beak's. See
  [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md)
  for what mounting the handler looks like.

## The checklist

Close these in order before a Beak backend faces the internet.

| Seam | Default | What production wants |
| --- | --- | --- |
| Authentication | Anonymous allowed | A `BeakAuthGuard` (the token guard, or your own) |
| Sessions | In-memory, per-process | A shared, persistent `TokenSessionStore` |
| Authorization | `BeakAllowAllPolicy` (open) | A `BeakPolicy` that gates by role |
| Row visibility | Every row | A `BeakRowPolicy` wherever "only their own" applies |
| Password secret | none | An env var read through `defaults.environment` |
| Uploads | Validated against the field's rules | Rules on every `@Image` and `@FileField` |
| Storage keys | Server-minted, traversal-rejecting | Left as-is (do not build keys from user input) |
| CORS | `*` | One origin, or `api.baseUrl: auto` |

## Continue reading

- [Auth and policies](../backend/auth-and-policies.md) the full auth surface and policy hooks.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) how the upload service resolves and drives a storage driver.
- [Files and storage columns](../models/files-and-storage-columns.md) the `@Image` and `@FileField` rules the validator enforces.
- [Environment and config](../deployment/environment-and-config.md) where secrets come from and how they are resolved.
- [Middleware](../backend/middleware.md) where CORS, auth, and error mapping sit in the request pipeline.
