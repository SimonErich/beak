---
title: How the admin app works
description: Follow one panel request through the gated Serverpod endpoint, Beak's in-process API and the session adapter down to Serverpod's own database.
type: concept
audience: [expert]
status: stable
---

# How the admin app works

After this page you can follow one click in the panel through Serverpod to a row in Postgres, and name the package that does each hop. The admin app has more moving parts than a bridge, and they are all small.

## The idea in one picture

```mermaid
flowchart LR
  subgraph app["bookshop_admin (Flutter web)"]
    P["BeakPanel"] --> H["HttpBeakDataSource<br/>BeakClient"]
    H --> T["ServerpodBeakHttpClient"]
  end
  T -->|"client.beakAdmin.dispatch(String)"| G
  subgraph srv["bookshop_server (one Serverpod process)"]
    G["BeakAdminEndpoint<br/>requireLogin + scope beak.admin"] --> E["BeakServerpodEngine"]
    E --> R["Beak's Shelf pipeline<br/>BeakPolicies"]
    R --> W["WormDataSource"]
    W --> A["ServerpodSessionAdapter"]
    A --> D[("session.db<br/>Serverpod's Postgres")]
  end
```

Everything left of the arrow is Beak's stock panel and HTTP client. Everything right of it is Beak's stock API, which does not know it is inside Serverpod. The two ends are joined by one string in and one string out.

## How it works

### The panel side

The panel is a normal `BeakPanel`. Its data source is Beak's `HttpBeakDataSource`, and the HTTP client under it is swapped for one that sends every request through a Serverpod call instead of a socket.

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_beak_data_source.dart"
--8<-- "packages/beak_serverpod_flutter/lib/src/serverpod_beak_data_source.dart:serverpodBeakDataSource"
```

The client sends no bearer token. The Serverpod client authenticates the `dispatch` call itself (JWT with refresh, in the example), and the URL's host is a placeholder: only the path and the query travel.

### The envelope

A Beak request becomes one JSON string, envelope version 1: `v`, `method`, `path`, `query`, `headers`, `body`. The answer is another string: `status`, `headers`, `body`. `BeakWireRequest` and `BeakWireResponse` live in `beak_serverpod` (pure Dart), so panel and server share the same two classes. Only four request headers survive the trip.

```dart title="packages/beak_serverpod/lib/src/wire.dart"
--8<-- "packages/beak_serverpod/lib/src/wire.dart:beakWireRequestHeaders"
```

No `authorization`, no `cookie`, no `x-forwarded-*`. Identity never comes from the envelope; the server takes it from the Serverpod session alone.

### The gate and the endpoint

The endpoint is one method. The gate is a mixin that overrides two getters, so Serverpod enforces sign-in and the scope before the method body runs. The scope has a name of its own:

```dart title="packages/beak_serverpod_server/lib/src/beak_admin_gate.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_admin_gate.dart:BeakScopes"
```

```dart title="packages/beak_serverpod_server/lib/src/beak_admin_gate.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_admin_gate.dart:BeakAdminGate"
```

```dart title="examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart:BeakAdminEndpoint"
```

The gate is getter-only on purpose. Serverpod's analyzer never turns mixin members into RPCs, so `serverpod generate` still produces exactly one connector, `dispatch`, while the getters gate every call at runtime. Your app's own admins, who hold `Scope.admin`, do not get the panel by accident.

### The engine

`BeakServerpodEngine` builds Beak's stock Shelf pipeline once per process and runs each envelope through it in memory. It is a top-level value, created once and shared by every request:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart:bookshopBeak"
```

`policy:` is required. There is no allow-all default. Per request, `dispatch` does this:

1. Decodes the envelope. A malformed one is a 400 (including a method that is not an HTTP method name), and an unsupported version says which version the server speaks.
2. Turns the path into an internal URL, or refuses with a 404. Only `/api/**` passes, and never `/api/auth/**`, because Serverpod owns sign-in. Percent-encoded dots, empty segments and separators are refused rather than resolved.
3. Reads `session.authenticated`. No session is a 401. The `admit` callback checks live admission and returns 403 when it refuses; its default requires the `beak.admin` scope even when the endpoint forgot `BeakAdminGate`. The principal resolver then turns the user into a `BeakPrincipal`: by default the user id, with every scope name as a role.
4. Runs the pipeline inside `BeakServerpod.runInSession`, so every statement Beak issues uses this request's session.
5. Sends request entries to `onRequest` and opaque failures to `onUnexpectedError`. Both default to `session.log`.

```dart title="packages/beak_serverpod_server/lib/src/beak_tunnel_path.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_tunnel_path.dart:apiOnly"
```

The principal reaches Beak's auth middleware through a request-context value of a private type. Only this library can construct one, so no header can forge an identity:

```dart title="packages/beak_serverpod_server/lib/src/beak_serverpod_engine.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_serverpod_engine.dart:TrustedGuard"
```

### Existing authorization and domain writes

An application with its own roles can pass `admit: (session, auth) => ...` to check current account status and permissions on every request. Keep `requireLogin => true` on its endpoint. Use `BeakAdminGate` only when that application also uses the stock `beak.admin` scope; a live admission callback cannot override a scope rejection Serverpod already made. The `principal` resolver supplies the roles used by `BeakPolicies`, independently of admission. Exceptions in admission or principal resolution return an opaque 500 and reach `onUnexpectedError`.

Pass `generateId` when the existing tables require a particular string identity, such as UUID v7. The engine forwards it to both direct CRUD and graph commits. `onRequest` and `onUnexpectedError` accept the application's logger callbacks without changing the pipeline.

`executeOperation` lets a graph operation call an existing use case inside the same Serverpod transaction as the graph and its receipt. Its `BeakSaveOperationContext` carries the prepared plan, target model, operation, resolved input values, existing record, resolved identity, principal and transaction-bound `WormDataSource`. Take the Session and optional transaction from `BeakServerpod.sessionOf(context.transaction.adapter)` and `BeakServerpod.transactionOf(context.transaction.adapter)` and pass both into the use case.

Return `BeakSaveOperationWrite(record: persistedRecord)` for a handled create or update, or `const BeakSaveOperationWrite()` for a handled delete or link write. Return null to use Beak's ordinary persistence. A handled operation skips that SQL, so a submitted value cannot overwrite what the domain use case calculated. Creates may use the identity assigned by the use case; subsequent operations resolve draft references to that identity. Beak rereads the persisted record, applies final graph validation, stores the receipt and skips the callback on replay. Policy, field, scope, scalar and revision checks run before the callback. A conditional operation locks its revision until commit. External mail or payment effects still belong in an outbox.

List domain-controlled models in `graphOnly` to close direct CRUD routes, which do not run this graph hook. Model `capabilities` describe the frontend transport; server policy must independently refuse unsupported create, update and delete operations.

Existing Serverpod tables can configure `@Resource` with `createdAtColumnKey`, `updatedAtColumnKey`, `deletedAtColumnKey` and optional `isDeletedColumnKey`. `beak prepare` reuses declared columns at these keys and emits the metadata; it does not add snake_case copies. With a boolean flag, false means live and true means deleted. Delete and restore keep the flag and deletion timestamp together across reads, relations, aggregates and conditional graph writes.

### The policy

The policy is Beak's `BeakPolicies`. A model with no rule is closed, so holding `beak.admin` opens the tunnel and grants nothing. `BeakAccess.role` takes a scope name because the default resolver turns scope names into roles.

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart:bookshopPolicy"
```

Nobody deletes: there is no `delete:` access on either rule, and a rule that is not written is a rule that is closed.

### The database

`WormDataSource` compiles Beak's queries to Postgres SQL, and `ServerpodSessionAdapter` runs them through `session.db.unsafeQuery` and `unsafeExecute` with positional parameters. It reads the session from a zone value, once per statement, so one adapter instance serves every request:

```dart title="packages/beak_serverpod_server/lib/src/beak_serverpod.dart"
--8<-- "packages/beak_serverpod_server/lib/src/beak_serverpod.dart:currentSession"
```

A graph commit opens a Serverpod transaction. A nested transaction is a savepoint, never flattened, so an inner failure rolls back only the inner work. Serverpod's database errors become worm exceptions, so a unique violation reads as a unique violation whether it happens mid-transaction or at `COMMIT`. Each statement carries a timeout, 30 seconds by default (`statementTimeoutInSeconds` on the engine).

```dart title="packages/beak_serverpod_server/lib/src/serverpod_session_adapter.dart"
--8<-- "packages/beak_serverpod_server/lib/src/serverpod_session_adapter.dart:transaction"
```

The adapter cannot create or change tables. `executeSchema` and `introspectSchema` throw `UnsupportedOperationException` with a pointer to `serverpod create-migration`.

### The receipts table

A form save is a graph commit, and a graph commit keeps a receipt so a retry is safe. Beak normally creates that table itself with a migration. Here Serverpod's migrations own it, so the server carries a model file, copied verbatim from Beak, and the engine maps Beak's receipt columns onto it.

```yaml title="examples/serverpod/bookshop_server/lib/src/beak/models/beak_commit_receipt.spy.yaml"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/models/beak_commit_receipt.spy.yaml"
```

The model is `serverOnly: true`, so it is not in the generated client. It is not in Beak's registry either, so `POST /api/beak_commit_receipt/query` answers 404, like any table Beak was not told about.

### Durable effects and pruning

`beakServerpodFrameworkTables` maps two Beak tables, not one: the receipts (`beak_commit_receipt`) and the effect outbox (`beak_outbox`). The example ships the receipts model only, because the example sends no mail. A project that delivers effects (a confirmation mail after a save, a payment request) adds a second `serverOnly` model next to the receipts one. This is the shape `beakServerpodFrameworkTables` expects:

```yaml
class: BeakOutboxEffect
serverOnly: true
table: beak_outbox
fields:
  effectKey: String, unique
  effectKind: String
  payloadJson: String
  deliveryStatus: String
  attemptCount: int
  availableAt: int
  leaseToken: String
  lastError: String
```

Then pass `beakServerpodFrameworkTables.outbox` wherever Beak takes an outbox table: `BeakOutbox.enqueue(..., table:)` in a `finalizePlan`, the `table:` of `BeakOutboxWorker` or `BeakOutboxSchedule`, and `BeakOutbox.prune(..., table:)`. Without it Beak looks for its own `_beak_outbox`, which Serverpod's migrations never create. The [durable effects](../../backend/durable-effects.md) page has the enqueue, delivery and retry rules; they are the same here.

What is not there:

- `BeakServerpodEngine` has no `outbox` parameter and starts no delivery loop. The host schedules a `BeakOutboxWorker` (or `BeakOutboxSchedule.start`) itself, on a database adapter that finds a Serverpod session, and stops it on shutdown.
- No test drives that loop end to end. `test/integration/beak/outbox_mapping_test.dart` in `examples/serverpod/bookshop_server` proves the table mapping on Serverpod's own database: an effect is enqueued once, delivered once, marked `delivered`, and a delivered row is pruned by age while a pending one stays.
- `finalizePlan` is passed through to Beak's router. The example uses none and no test on this path exercises it.

Nothing prunes either table automatically. Schedule `engine.pruneReceipts(session, olderThan: cutoff)` from a host future call or script; it uses Beak's existing pruning implementation and the engine's receipt mapping. `cutoff` is a UTC `DateTime`, and only earlier receipts are deleted. Retain receipts longer than any supported retry window: a pruned save id is a new save.

```dart
final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
await BeakCommitReceipt.db.deleteWhere(
  session,
  where: (t) => t.createdAt < cutoff,
);
```

`BeakOutbox.prune(adapter, olderThan: ..., table: beakServerpodFrameworkTables.outbox)` does the same for delivered effects, with the same rule about the cutoff: pruning ends the duplicate protection for the rows it removes.

### The server-only column

`book.supplierCostInCents` is declared `scope=serverOnly` in `book.spy.yaml`, and the Beak `Book` class does not declare it. Serverpod keeps it out of the client.

Beak's data source selects, returns and stores in receipts only the columns its models declare, so a `SELECT *` never happens.

A test proves it against a real database: the value is in the row, and it is in no list, single read, batch, patch, graph-commit reply, header, CSV export or receipt. Sending the column in a create, an update or a commit is refused (422, or an incomplete receipt).

## Why it is shaped this way

One endpoint instead of one per table, because Beak's API is a REST surface: query, read, create, patch, delete, batch, summary, export, commits and more, per table. A string-in, string-out method carries all of it, so there is nothing to write per table and no second protocol to keep in step. The price is that Serverpod's generated client sees an opaque string, and every panel call is a Serverpod call with Serverpod's body cap (`maxRequestSize`, 512 KiB in the template's config).

The adapter rides the request's session instead of opening a connection. That gives Beak Serverpod's pool, its logging and its transactions, and leaves nothing extra to deploy. The price is that the panel shares the pool with your app: an expensive export competes with your real traffic.

The mirror classes are written by hand. Nothing generates a Beak schema class from a `.spy.yaml` file yet. The example keeps the two honest with a test that fails when a Beak column is not a physical column, when the supplier cost gets modelled, or when the `BookFormat` enums differ. It compares names, not types or nullability.

## What it means for you

- You never write a Beak migration and never give Beak a database URL. Serverpod migrates, Beak reads and writes.
- You never write an endpoint per table. You write one gated endpoint, once, and a policy that names every model and operation it allows.
- You do write, per table, a schema class that mirrors the `.spy.yaml` model, and you leave out every column the admin must not see.
- Deleting, unlisted models and unlisted operations are closed until the policy opens them.

## Continue reading

- [Setting up the admin app](setup.md): build this, file by file.
- [Limits and next steps](limits-and-next-steps.md): what the proof does not cover.
- [Graph commits](../../architecture/graph-commits.md): what happens inside a form save.
