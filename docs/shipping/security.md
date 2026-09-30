---
title: Security
description: "Close the seams of a Beak backend before it faces the internet: sessions, deny-by-default policies, row scopes, uploads, CORS and the limits that remain."
type: guide
audience: [expert]
status: stable
---

# Security

A Beak backend generates its whole API from your models, which means it generates the whole attack surface too. The defaults are open on purpose, so that a fresh project works before you have written a line of auth. This page walks the seams in the order to close them, and says plainly which parts Beak does not cover. After it you can put a Beak server on the internet knowing which guarantees are the framework's and which are yours.

!!! warning "The panel is not the boundary"
    Hiding a resource in `beak.yaml` or a button behind a role check in the panel is presentation. The API stays where it is, and a client that skips the panel skips every UI check with it. Everything on this page runs in the backend, which is the only place a rule holds.

## At a glance

Security for a generated backend lives in one file, `lib/server.dart`. `beak eject server` writes the starter, which returns the defaults unchanged. After editing it, run `beak prepare`; until you do, the generated host does not call your function.

| Seam | Default | What production wants |
| --- | --- | --- |
| Who is calling | No guard: every request is anonymous | `authSessions` for development, your own `BeakAuthGuard` for real accounts |
| Sessions | In process memory, 12 hours, lost on restart | A `TokenSessionStore` over shared storage |
| What they may do | `BeakAllowAllPolicy`: everything | `BeakPolicies`: only what a rule lists |
| Which rows | Every row | `rowScope` wherever "only their own" applies |
| Which fields | Every field | `hiddenFields` to hide one, `readOnlyFields` for server-owned values |
| Uploads | Validated against the column, held to 100 MiB if the column sets no limit | `maxSizeInBytes` and `allowedTypes` on every upload column |
| CORS | `*` | `corsOrigin:` with the panel's origin, or one shared origin |
| TLS | None, plain HTTP | Terminate at a proxy; keep the Beak port private |
| Rate limits | None | A proxy rule or a Shelf middleware |

The smallest closed server names a policy, and, while you develop, a session store with one account. The two pieces below come from Beak's test suite; the wiring between them is illustrative and uses only real parameters of `defaults.build`.

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
--8<-- "packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart:policyRules"
```

```dart title="packages/beak_backend/test/src/server/beak_server_api_test.dart"
--8<-- "packages/beak_backend/test/src/server/beak_server_api_test.dart:authSessionsFixture"
```

```dart
// Illustrative: lib/server.dart. `notesPolicy` stands for the BeakPolicies
// built by the first block and `sessions` for the function in the second.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  policy: notesPolicy,
  authSessions: sessions(),
  corsOrigin: 'https://admin.example.com',
);
```

## Authentication: who is this request

Authentication is one interface, `BeakAuthGuard`. The auth middleware calls it on every request.

```dart title="packages/beak_backend/lib/src/auth/beak_auth_guard.dart"
--8<-- "packages/beak_backend/lib/src/auth/beak_auth_guard.dart:BeakAuthGuard"
```

The contract has one sharp edge. `null` means anonymous, meaning no credentials at all. Credentials that are present and wrong must throw a `BeakAuthenticationException`, never return `null`, so a forged token is a 401 and does not quietly become an anonymous request.

`authSessions:` mounts `POST /api/auth/login`, `POST /api/auth/logout` and `GET /api/auth/me`, and installs a `TokenSessionAuthGuard` over the same store, which reads opaque `Bearer` tokens. Pass `authGuard:` to identify callers another way (a JWT, a gateway header); an explicit guard takes over from the sessions'.

### The built-in login is for development

`BeakAuthSessions` is enough to sign in to a panel while you build it. It is not an account system, for these reasons:

| Property | What it is | Why it matters |
| --- | --- | --- |
| Accounts | A `List<BeakUserAccount>` built at boot | No user table, no password change, no disabling an account without a deploy |
| Password hash | HMAC-SHA256 under one shared secret | A fast hash with no per-user salt and no work factor; not a password KDF |
| Comparison | A plain string comparison of hashes | Not constant-time |
| Login attempts | Not counted, throttled or locked out | Every attempt is a 401 line in the request log and nothing more |
| Sessions | `InMemoryTokenSessionStore`, per process | A restart signs everyone out, and a second process does not know the first one's tokens |

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
--8<-- "packages/beak_backend/lib/src/auth/auth_router.dart:hashBeakPassword"
```

Tokens themselves are sound: 256 bits from `Random.secure()`, hex-encoded, 12 hours by default (`sessionTtl`). The weak parts are the accounts and the store around them.

For production, put the identity somewhere that already does this well and let Beak consume it. Implement `BeakAuthGuard` over your identity provider or gateway, and implement `TokenSessionStore` over shared storage if you keep Beak's own sessions:

```dart title="packages/beak_backend/lib/src/auth/token_session_store.dart"
--8<-- "packages/beak_backend/lib/src/auth/token_session_store.dart:TokenSessionStore"
```

Two things you do not have to do: write a password reset flow (the built-in surface has none, and an identity provider brings its own), and touch the panel. The panel's sign-in screen talks to whatever the backend's `/api/auth` answers, and its token lives in memory only, so a browser reload signs out. A Serverpod backend takes its authentication from Serverpod; see [Authentication](../serverpod/authentication.md).

Put the secret you hash with in the resolved environment and read it through `defaults.environment`, so a test that injects an environment injects it here too. Beak has no environment variable of its own for it. The name is yours.

## Authorization: what may this request do

Authentication answers "who". A policy answers "may they". Every generated handler asks the policy before it acts, and a denial becomes the right status by itself: 401 for an anonymous caller, 403 for a signed-in one.

The default is `BeakAllowAllPolicy`, which permits everything. It exists so a new panel works before any auth does, and it is also why a server that ships without a policy ships an open door. `BeakServeHost` binds `0.0.0.0` by default, so that is the shipped combination until you change it. A server that listens beyond loopback with it prints one line at boot, `warning: Beak is listening on 0.0.0.0:8080 with BeakAllowAllPolicy, ...`, and serves anyway. Treat the line as a failed check, not a notice.

`BeakPolicies` is the production shape. It denies whatever it does not list. Each `BeakModelRules` states who may read, write and delete a model, which rows a principal sees, which fields the server owns and who may run each named action. A part left out is denied:

```dart title="packages/beak_backend/lib/src/auth/beak_policies.dart"
  BeakModelRules(
    this.model, {
    this.read,
    this.write,
    this.delete,
    this.rowScope,
    Set<BeakFieldRef<Object>> readOnlyFields = const {},
    Map<BeakFieldRef<Object>, BeakAccess> hiddenFields = const {},
    Map<BeakModelAction, BeakAccess> actions = const {},
    // ...
```

Who qualifies is a `BeakAccess`: `BeakAccess.role('staff')`, `BeakAccess.authenticated`, `BeakAccess.anyone`, and `any`, `all` and `not` to combine them. An empty `any` or `all` grants nothing, so a list that lost its entries never opens a resource.

A model with no rule is invisible: its endpoints answer 401 to an anonymous request and 403 to anyone else, and no other model's relationship exposes it. A model you add next month is closed until someone opens it. The test that pins this is worth reading, because it walks six routes:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
--8<-- "packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart:unlistedModelTests"
```

### Row scopes narrow, they do not refuse

`read: authenticated` answers "may this caller read orders at all". It does not answer "may this caller read these orders". Without a row scope, a policy meant as "customers see only their own orders" is bypassed by a query with any filter the caller writes, because the filter comes from the client. A `rowScope` is intersected with every read and write of the model: query, aggregate, get-one, update, delete, graph commits and export. A create, and an update that changes a field the scope reads, is also judged on the row it leaves behind, so a caller cannot write a record into another owner's rows or hand one of their own away (`403`). Relation loads and filters that reach a related model apply that model's scope as well.

The scope is a typed filter built from the model's fields (`NoteModel.authorId.eq(principal.id)`), so renaming the field is a compile error here and not a policy that silently matches nothing. An anonymous request has no principal to build a scope for and sees no rows.

Refusing and narrowing are different answers. `canView` false is a refusal: 403, no data. A scope is not a refusal. The request succeeds and the rows that are not the caller's are not in the answer. Use the refusal when the table is none of their business and the scope when some of it is.

### Fields and actions

Read access to a field also gates searching, sorting, filtering and aggregating by it, so a hidden column cannot be inferred from the order of the rows. `hiddenFields` hides a field from the principals its access value names. `readOnlyFields` names values the server owns (a calculated total, a number minted at creation): a request that supplies one is rejected with a 422 field error, and forms are told not to offer it. Values the server derives itself are unaffected. A request that names a field the model does not have is a 422 too, so there is no mass-assignment path to an unmodelled column.

Graph commits authorize every operation: field write access for what the client sent, the table policy for create, update and delete, and the owner's update right for children. Operations a `preparePlan` hook adds skip the field check, because a derived column is often one the client may not write, and every other check still applies to them.

For a rule `BeakPolicies` cannot express, implement `BeakPolicy`, `BeakRowPolicy`, `BeakFieldPolicy` or `BeakActionPolicy` yourself. Extend `BeakAllowAllPolicy` if you only want to restrict a few operations.

## Uploads

An upload runs through the column's rules on the server before a byte is stored. Size, type and image dimensions are declared once on the column and enforced twice, in the browser and in the API:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_image.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product_image.dart:productImageColumn"
```

What this does and does not check, verified against the running shop:

- Size is checked while the part streams in, so an oversized file never buffers fully. A column that sets no `maxSizeInBytes` is held to 100 MiB, because the body is read into memory. Set the limit you mean on every column.
- Type is the MIME type the client declared plus the file extension. A GIF declared as `image/gif` on this column is a 422 (`The MIME type "image/gif" is not allowed`). An empty `allowedTypes` means unrestricted.
- Content is checked only for image columns. They decode the bytes, so a text file named `x.png` is a 422 (`The uploaded file is not a supported raster image`). A file column does not look inside the file.
- The key is minted on the server from a fresh uuid. The client's filename never reaches the key, so `../../other/logo.png` cannot choose where bytes land. The extension comes from the validated MIME type when Beak knows the type, and from the client's filename when it does not, and then only when it is one to sixteen letters and digits (`report.a/b` and `x.php\r\nDELE y` store with no extension).

That last point has a consequence. A file column with no `allowedTypes` accepts a file named `evil.html` declared as `text/html`, and stores it as `<uuid>.html`. The local driver serves stored files with a content type taken from the extension, and adds `x-content-type-options: nosniff` and a sandboxing `content-security-policy`, and makes HTML, SVG and XML a download, so the file does not run as a page on your API's origin. It is still a file you host. Always list `allowedTypes`. Do not allow `BeakFileType.svg` (it can carry script) unless you serve uploads from a separate origin, and prefer to serve uploads from a separate origin regardless.

Every driver shares one key validator, which rejects anything that could leave the storage root, and control characters, which would end an FTP command early:

```dart title="packages/beak_core/lib/src/storage/beak_storage_key.dart"
--8<-- "packages/beak_core/lib/src/storage/beak_storage_key.dart:validate"
```

Stored files are public by design. The local driver serves `/uploads/...` with no authentication, and the URL is the only secret. The read route, `GET /api/<table>/<column>/upload?key=`, does check the read policy and the row scope, but it hands back a URL that then works for anyone who holds it. On a private S3 bucket that URL is presigned and expires after `signedUrlLifetime` (default one hour); with `BEAK_S3_PUBLIC_BASE_URL` set, or on the local, FTP and memory drivers, it is the permanent public address. The URL in the upload response is always the plain one. Files that must stay private need a proxy in front of the driver that authorizes the read. The upload and delete routes follow the write and delete rules of `BeakPolicies`.

## CORS, TLS and headers

Browsers enforce CORS. `curl` ignores it, and so does anything else that is not a browser, so it narrows which web pages can read your API and authenticates nobody. The middleware answers `OPTIONS` preflights with 204 and puts these headers on every response:

```dart title="packages/beak_backend/lib/src/server/middleware/cors_middleware.dart"
--8<-- "packages/beak_backend/lib/src/server/middleware/cors_middleware.dart:beakCorsMiddleware"
```

The default origin is `*`. Name the panel's origin with `defaults.build(corsOrigin: 'https://admin.example.com')`. It takes one origin, not a list. If the panel and the API answer from one origin (the reverse proxy sends `/api` to Beak), the panel makes no cross-origin call at all; see [Going to production](going-to-production.md). Tokens travel in the `Authorization` header and Beak sets no cookies, so a page in another tab has no ambient credential to abuse.

Because tokens are bearer tokens, the connection must be HTTPS. Beak listens on plain HTTP. Terminate TLS at the proxy and keep the Beak port off the public interface, with `HOST=127.0.0.1` when the proxy is on the same host or a private container network otherwise.

Response headers come from three places. `dart:io` adds `x-content-type-options: nosniff`, `x-frame-options: SAMEORIGIN` and `x-xss-protection`. Beak adds `x-request-id`. Nothing adds `Strict-Transport-Security` or a `Content-Security-Policy`, and the repository's `deploy/nginx.conf` does not either. Add them at the proxy.

## Errors, logs and what a response reveals

The error-mapping middleware is the one catch boundary. A typed `BeakException` becomes its status and JSON body; anything else becomes an opaque 500 with the message `Internal server error.` and the request id, and the real error goes to the `onUnexpectedError` listener (stderr by default). Two typed exceptions are 500s that carry their message as written: `BeakConfigurationException` and `BeakInternalException`. A `BeakStorageException` does not: a storage driver's message can include an endpoint or a bucket name, so the caller gets `File storage failed.` and the full message goes to `onUnexpectedError`.

The request log records the method, the path (without the query string), the status, the duration and the request id. It never records bodies or tokens. The probes `GET /healthz` and `GET /readyz` sit outside `/api` and outside authentication, on purpose, and a failing `/readyz` names no cause.

## Known gaps

These are limits of the current implementation. Each is worth a decision before launch.

| Gap | What happens | What to do |
| --- | --- | --- |
| The `perPage` ceiling is 200 unless you set `maxPerPage` | A request for 100,000 rows gets 200 and an envelope that says so | Nothing, unless 200 is too generous; `defaults.build(maxPerPage: 50)` lowers it for every model |
| JSON bodies are capped at 16 MiB, uploads have their own limits | A larger JSON body is a `413` and the read stops when the cap is crossed; a body under the cap is still read whole | `client_max_body_size` at the proxy, well under 16 MiB |
| A caller who may read a model can list its soft-deleted rows | `"withTrashed": true` in a query, aggregate, summary or export spec includes them, and only bringing one back (`restore`) asks for `canUpdate` | Do not soft-delete what a reader must never see again; use `force` deletes, or a `rowScope` that hides deleted states |
| No rate limiting, on login or anywhere | Unlimited attempts | A proxy rule, or a Shelf middleware in `middleware:` |
| A `BeakSemantic.password` column is write-only over HTTP | No response carries its stored value, and a filter, sort or aggregate over it is a `422`. The value you send on a create is stored as sent | Store a hash, never the password: hash it in your own preparer or action before it is written |
| Unrestricted file columns keep the client's extension | See Uploads | Always set `allowedTypes` |
| Image decoding happens on the request isolate | The header is checked first and `ImageTransformRunner` refuses more than 50 million pixels, but a large legal image still stalls the process for a moment | Set `maxSizeInBytes` and `maxDimensions`; see [Performance](performance.md) |
| Draft persistence is plain JSON in browser storage | Anyone with the browser profile can read it | Use `BeakFormDrafts` only where that is acceptable; scope its `context` to the user and tenant, never to a token |

## Rules and limits

- A policy is evaluated on the server for every route, including uploads, export and graph commits. The panel's `canX` flags only hide controls.
- One `BeakPolicies` per server, one `BeakModelRules` per model. A second rule for the same model is a boot error, and so is a `readOnlyFields` or `hiddenFields` entry or action the model does not declare.
- A row scope must not reach a model that scopes back to the first one. That is reported as a configuration error at request time.
- `authSessions` alone installs a `TokenSessionAuthGuard` over its own store, so the tokens it mints are checked. Pass `authGuard` only to identify callers some other way.
- Secrets belong in the environment, not in `beak.yaml` and not in a committed `.env`. `.env` is git-ignored in Beak's own repository; yours needs the same entry.

## Verify it

Check the policy with real requests. The shop ships without one, so an anonymous query is answered in full:

```console
$ curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/api/products/query \
    -H 'content-type: application/json' -d '{"table":"products"}'
200
```

With a `BeakPolicies` that does not list the model, or does not let anonymous callers read it, the same request must print 401. Test each role with a token from `/api/auth/login`, and assert the row-scoped answers:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
--8<-- "packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart:rowScopedQueryTests"
```

Look at what a browser sees. A preflight from any origin is answered with `*` by default:

```console
$ curl -s -i -X OPTIONS http://localhost:8080/api/products/query -H 'Origin: https://evil.example' | grep -i access-control-allow-origin
access-control-allow-origin: *
```

With `corsOrigin` set, that line carries your origin instead.

`beak doctor` does not audit policies. The tests above are the audit.

## Reference

- `packages/beak_backend/lib/src/auth/` holds the guard, the sessions, the policies and the query authorizer.
- `packages/beak_backend/lib/src/server/middleware/` holds the CORS, error-mapping, request-log and auth middleware.
- [Auth and policies](../backend/auth-and-policies.md) is the backend guide to the same hooks.
- [REST API](../reference/rest-api.md) lists the auth routes and the error envelope.

## Continue reading

- [Testing](testing.md) how to run the policy checks above against a real server.
- [Environment and config](environment-and-config.md) where secrets come from and how they resolve.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the drivers behind the upload rules.
