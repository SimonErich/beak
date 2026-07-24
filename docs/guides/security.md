---
title: Security
description: The security seams of a Beak backend: authentication guards, per-resource policies, the password secret, upload validation, storage-key hardening, and CORS.
---

# Security

After this page you can lock down a Beak backend: authenticate requests, gate
every generated endpoint by role, keep the password secret out of source, and
trust that uploads and storage keys cannot be used to write where they should
not.

Beak generates the whole CRUD surface for you, which means it also generates the
whole attack surface for you. The defaults are deliberately open (a fresh panel
works with no auth at all) so you configure security on purpose, not by
accident. This page walks the seams in the order you should close them.

## Authentication: who is this request

Authentication in Beak is one interface, `BeakAuthGuard`. It resolves the
identity behind a request, and it is the pluggable seam the auth middleware
calls on every request.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
abstract interface class BeakAuthGuard {
  /// The principal behind [request], or `null` when it carries no
  /// credentials.
  Future<BeakPrincipal?> authenticate(Request request);
}
```

The contract has a sharp edge worth internalizing: `null` means anonymous (no
credentials at all), but credentials that are present and wrong must throw, not
return `null`.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
/// Implementations return `null` for anonymous requests (no credentials at
/// all) and throw a [BeakAuthenticationException] for credentials that are
/// present but invalid, so forged tokens never demote silently to
/// anonymous.
```

The built-in guard, `TokenSessionAuthGuard`, reads opaque `Bearer` tokens and
looks them up in a server-side session store. A missing header is anonymous; a
malformed or unknown token throws.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
final store = InMemoryTokenSessionStore();
final handler = const Pipeline()
    .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
    .addHandler(router);
```

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
also why shipping without a real policy ships an open door.

```dart title="packages/beak_backend/lib/src/auth/beak_policy.dart"
/// The default policy: everything is allowed - panels stay open until an
/// app configures a real policy.
final class BeakAllowAllPolicy implements BeakPolicy {
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

### Wiring it together

Authentication and authorization are three pieces that share one store: the
sessions the login endpoint mints into, the guard that reads them back, and the
policy that judges the resulting principal.

```dart title="packages/beak_backend/test/src/auth/policy_test.dart"
final store = InMemoryTokenSessionStore();
handler = const Pipeline()
    .addMiddleware(beakJsonMiddleware())
    .addMiddleware(beakErrorMappingMiddleware())
    .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
    .addHandler(
      beakApiRouter(
        registry: registry,
        dataSource: WormDataSource(registry, adapter: adapter),
        policy: const _AdminOnlyWrites(),
      ),
    );
```

`BeakServer` accepts the same three as parameters (`authSessions`, `authGuard`,
`policy`) and assembles the pipeline for you. The `authSessions` store and the
`authGuard`'s store must be the same instance, or a freshly minted token will
not be recognised.

## The password secret

Accounts never store plaintext. `hashBeakPassword` derives an HMAC-SHA256 hash
under a secret, and login recomputes the hash to compare.

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
/// Hashes [password] with HMAC-SHA256 under [secret] - what
/// [BeakUserAccount]s store instead of plaintext.
String hashBeakPassword(String password, {required String secret}) =>
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(password)).toString();
```

The same secret that hashed an account's password must be handed to
`BeakAuthSessions`, so login can recompute and compare. That secret is the one
value here you must keep out of source. Load it from the environment (the same
way Beak loads `DATABASE_URL`), for example an env var named `BEAK_AUTH_SECRET`,
and read it through `BeakEnv.resolve()`:

```dart
final authSecret = BeakEnv.resolve()['BEAK_AUTH_SECRET']!;
final auth = BeakAuthSessions(
  store: InMemoryTokenSessionStore(),
  secret: authSecret,
  users: [
    BeakUserAccount(
      username: 'admin',
      passwordHash: hashBeakPassword('s3cret', secret: authSecret),
      principal: const BeakPrincipal(id: 'admin', roles: {'admin'}),
    ),
  ],
);
```

!!! danger "The secret lives in the environment, never in a commit"
    Beak's env loading exists precisely so secrets stay out of the repo: the
    real process environment always wins, `.env` is git-ignored, and only a
    `.env.example` documenting the keys is committed. Rotating the secret
    invalidates every stored hash, so treat it as long-lived and back it up.

## Upload validation

Every upload runs through `BeakUploadValidator` before a byte is stored. It
enforces the column's file rules (size, allowed MIME types and extensions,
maximum dimensions, aspect ratio) and returns a typed result you cannot ignore.

```dart title="packages/beak_core/lib/src/storage/beak_upload_validator.dart"
BeakResult<BeakUpload> validate(
  BeakUpload upload, {
  int? maxSizeInBytes,
  List<BeakFileType> allowedTypes = const [],
  BeakDimensions? maxDimensions,
  double? aspectRatio,
  BeakDimensions? actualDimensions,
});
```

Type checks look at both the MIME type and the file extension, so a `.php`
renamed to `.png` fails on one axis or the other. Failures aggregate into a
`BeakValidationException` keyed by `size`, `type`, `dimensions`, and
`aspectRatio`, which the handler maps to a 422 with per-aspect messages.

### Never trust the client's filename

The name the browser sends is display text, not a path. Beak mints the storage
key server-side from a fresh uuid plus the extension derived from the validated
MIME type; the client filename is never used to build a key.

```dart title="packages/beak_backend/lib/src/uploads/upload_service.dart"
/// [generateKeyId] injects the storage-key mint for tests (defaults to
/// uuid v4) - client filenames are never trusted for keys.
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

`*` is convenient for local development where the panel and server run on
different ports. In production, name the exact origin your panel is served from
by placing `beakCorsMiddleware(allowedOrigin: 'https://admin.example.com')` in
your own pipeline around `beakApiRouter`, rather than accepting the `*` default.

## The checklist

Close these in order before a Beak backend faces the internet.

| Seam | Default | What production wants |
| --- | --- | --- |
| Authentication | Anonymous allowed | A `BeakAuthGuard` (the token guard, or your own) |
| Sessions | In-memory, per-process | A shared, persistent `TokenSessionStore` |
| Authorization | `BeakAllowAllPolicy` (open) | A `BeakPolicy` that gates by role |
| Password secret | none | `BEAK_AUTH_SECRET` from the environment |
| Uploads | Validated against column rules | Rules on every file column; codec-decoded dimensions |
| Storage keys | Server-minted, traversal-rejecting | Left as-is (do not build keys from user input) |
| CORS | `*` | The exact panel origin |

## Continue reading

- [Auth and policies](../backend/auth-and-policies.md) the full auth surface and
  policy hooks.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) how the
  upload service resolves and drives a storage driver.
- [Files and storage columns](../models/files-and-storage-columns.md) the
  column-level file rules the validator enforces.
- [Middleware](../backend/middleware.md) where CORS, auth, and error mapping sit
  in the request pipeline.
