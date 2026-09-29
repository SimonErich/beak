# beak_backend

The Shelf server of Beak. From a registry of models it builds a REST API with
query, batch, relation, aggregate and summary endpoints, atomic graph commits
with a durable outbox, validated uploads, auth, health probes and CSV export,
all executed by the worm ORM.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. You write no endpoint per table.

## When you depend on it

An app does not. It imports `package:beak/server.dart` from the
[`beak`](https://github.com/SimonErich/beak/tree/main/packages/beak) umbrella,
and `beak prepare` writes the host that starts the server. Depend on
`beak_backend` directly to mount the generated API inside a Shelf app you
already run (see [Embedding](#embedding-in-your-own-shelf-app)) or to write a
server-side adapter.

## What the API covers

Every registered model gets a router under `/api/<table>`. The rest is mounted
once per server.

| Route | What it does |
| --- | --- |
| `POST /query`, `/aggregate`, `/summary`, `/batch` | A `BeakQuerySpec` in; a page, a number, grouped rows or several records out. |
| `POST /validate` | Checks unique and existence constraints without writing. |
| `GET /capabilities` | What the current principal may do with this model, or with one record given `?id=`. |
| `POST /`, `GET /<id>`, `PATCH /<id>`, `DELETE /<id>`, `POST /<id>/restore` | Per-record reads and writes. Writes are closed for graph-only models and for models whose behavior or shared rules span a relationship. |
| `POST /<id>/relations/<key>/attach`, `/detach` | Many-to-many links. |
| `POST /export` | CSV export of a query. |
| `POST`, `GET`, `DELETE /<columnKey>/upload` | Validated uploads, when a storage driver is configured. Images run through `beak_image`. |
| `POST /api/commits`, `GET /api/commits/<saveId>` | Graph commits: a form save as one transaction, with a receipt that makes a retry idempotent. |
| `POST /api/auth/login`, `/logout`, `GET /me` | Token sessions, when `authSessions` is set. |
| `GET /healthz`, `/readyz` | Liveness, and readiness with a generic detail. Outside `/api` and open to anonymous callers; a request that sends an invalid token still gets a `401`. |

The middleware stack around the router is request log, CORS, JSON, error
mapping, auth, then your own. The error mapping is the single catch boundary: it
turns the sealed `BeakException` family into HTTP status and JSON.

## Customize the server you get

`beak prepare` writes `lib/beak/server.g.dart` (a `BeakServeHost` holding every
model, migration and seeder) and the `bin/serve.dart` and `bin/migrate.dart`
entrypoints that call it. The part that is yours is `lib/server.dart`: the host
hands it the resolved `BeakServerDefaults`, and `defaults.build(...)` takes
whatever you want to change.

```dart title="examples/clean_beak_config/lib/server.dart"
/// Adds the example's transactional shop invariants to the generated host.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
  graphOnly: const [
    OrderModel(),
    OrderItemModel(),
    InvoiceModel(),
    InvoiceItemModel(),
    InvoiceVoucherModel(),
    ProductModel(),
    ProductVariantModel(),
    VariantAttributeModel(),
    ProductAttributeModel(),
    CategoryAttributeModel(),
    VoucherModel(),
    TaxRateModel(),
  ],
);
```

`preparePlan` runs the business rules of a graph commit inside its transaction,
and `graphOnly` closes the per-record routes of the models those rules govern,
so no request can skip them. `beak eject server` writes a starter
`lib/server.dart` that lists every hook.

| `build(...)` argument | What it does |
| --- | --- |
| `policy` | Who may do what. The default allows everything (see Limits). |
| `authSessions`, `authGuard` | Token sessions and the code that turns a request into a principal. |
| `preparePlan`, `finalizePlan` | Transactional rules before and after a graph commit. |
| `graphOnly` | Models that can only be written through graph commits. Needs `preparePlan`. |
| `outbox` | A `BeakOutboxSchedule`: effects the finalizer enqueued, delivered while the host serves. |
| `middleware`, `routes` | Middleware after auth, and endpoints tried before the generated API. |
| `corsOrigin`, `onRequest`, `onUnexpectedError` | The allowed origin, the request log, and where unexpected failures go. |
| `generateId`, `transformRunner` | The id mint and the image pipeline. |

The outbox, extra routes and middleware together (`sendReceipt`, `stats` and
`rateLimit` are yours):

```dart
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  outbox: BeakOutboxSchedule(
    interval: const Duration(seconds: 5),
    handlers: {'receipt': sendReceipt},
  ),
  routes: (Router()..get('/api/stats', stats)).call,
  middleware: [rateLimit()],
  corsOrigin: 'https://admin.example.com',
);
```

`BeakServeHost.serve()` validates the outbox schedule before it binds the port,
starts the schedule once the socket is bound, and stops it when the returned
server closes. With `DATABASE_URL=sqlite::memory:` it also applies the
migrations and runs the seeders in the serving process, because that database
exists nowhere else.

## Who may do what

`BeakPolicies` is a typed rule set that denies everything it does not list. A
model with no rule is invisible, and holding a role opens only what a rule
names. The Serverpod example's policy, in full:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart"
/// Who may do what in the bookshop admin.
///
/// Deny by default: holding `beak.admin` opens the tunnel and grants nothing.
/// Staff (the `bookshop.staff` scope) read and write authors and books.
/// Nobody may delete: a rule that is not written is a rule that is closed, so
/// removing an author (and, by cascade, their books) needs a deliberate rule.
final BeakPolicies bookshopPolicy = BeakPolicies(
  rules: [
    BeakModelRules(const AuthorModel(), read: _staff, write: _staff),
    BeakModelRules(const BookModel(), read: _staff, write: _staff),
  ],
);

final BeakAccess _staff = BeakAccess.role(BookshopScopes.staff.name!);
```

`BeakModelRules` also takes `delete`, a `rowScope` (a typed filter built for the
signed-in principal), `readOnlyFields` the server owns, and per-action access.
`BeakAccess` has `role`, `authenticated`, `anyone`, `any`, `all` and `not`.
Pass the policy as `policy:` to `defaults.build`, together with an
`authSessions` or `authGuard` that produces principals. Without one every
request is anonymous, and a role rule never matches an anonymous request.

The lower-level `BeakPolicy`, `BeakRowPolicy`, `BeakFieldPolicy` and
`BeakActionPolicy` interfaces stay available for rules that do not fit the
DSL. Panel permissions only hide controls; this is where access is decided.

## Adopting a database you did not create

`BeakBaselineMigration` is the migration `beak introspect` writes for a
database that already exists. On that database it changes nothing and is
recorded as applied. On an empty one it builds every listed table from the
models. It never alters a table that is already there.

## Embedding in your own Shelf app

`BeakServer` is the whole stack as one Shelf `Handler`:

```dart
final config = BeakBackendConfig.fromEnv();
final registry = buildBeakRegistry();
final server = BeakServer(
  config: config,
  registry: registry,
  dataSource: WormDataSource(
    registry,
    adapter: adapterFromUrl(config.databaseUrl),
  ),
);
final http = await server.start();
```

`buildBeakRegistry()` is the generated one from `lib/beak/registry.g.dart`. Use
`server.handler` instead of `server.start()` to mount it under a router you own.
`BeakBackendConfig.fromEnv()` reads `DATABASE_URL` (default `sqlite:beak.db`),
`PORT` (default 8080) and `HOST` (default `0.0.0.0`). Migrations and seeders
still run through `BeakServeHost.runCli`, which the generated
`bin/migrate.dart` calls.

## Main types

| Type | What it is |
| --- | --- |
| `BeakServeHost` | Environment, database, storage and serving, plus the migration and seeding CLI (`runCli`). |
| `BeakServerDefaults` | What the host resolved. `build(...)` returns the standard server with your changes. |
| `BeakServer` | The middleware stack around the API. `handler` is the Shelf handler, `start()` binds the socket. |
| `beakApiRouter` | The generated API as one `Handler`, for a stack you assemble yourself. |
| `WormDataSource` | The default `BeakDataSource`, executing every operation on a worm `DatabaseAdapter`. |
| `BeakSavePlanPreparer`, `BeakSavePlanFinalizer` | The typedefs of the transactional hooks behind `/api/commits`. |
| `BeakOutbox`, `BeakOutboxSchedule`, `BeakOutboxWorker` | Effects enqueued inside a commit and delivered after it, with leases and bounded retries. |
| `BeakPolicies`, `BeakModelRules`, `BeakAccess` | The typed, deny-by-default rule set. |
| `BeakAuthGuard`, `BeakAuthSessions`, `TokenSessionAuthGuard` | Turning a request into a principal. |
| `BeakBackendConfig` | Validated database URL, host and port. |
| `adapterFromUrl`, `initializeBeakDatabase` | Open the database a `DATABASE_URL` names. |

## Limits

- **Open by default.** `BeakServer` and `defaults.build` use
  `BeakAllowAllPolicy`, answer CORS with `*` and bind `0.0.0.0`, and nothing
  warns at boot when that combination is exposed. Set a policy and
  `corsOrigin`, and `HOST=127.0.0.1` for local work, before a server is
  reachable from anywhere you do not control.
- **Graph commits need worm.** `POST /api/commits` is mounted only when the
  data source is a `WormDataSource`, and `preparePlan`, `finalizePlan` and
  `graphOnly` throw at startup with any other. A panel that saves through a
  different source has no commit route to call.
- **The page-size ceiling is 200, and fixed for the generated server.**
  `BeakQueryAuthorizer` and `BeakCrudHandlers` take a `maxPerPage`, but
  `BeakServer` does not pass one through yet. A request for more rows is served
  at the ceiling and the page envelope says so.
- **Upload URLs are not signed.** `GET .../upload` asks the driver for a plain
  URL, so a private S3 bucket does not serve through it.
- **Unexpected failures are opaque.** Anything that is not a `BeakException`
  becomes a 500 with code `internal` and a fixed message. The raw error goes to
  `onUnexpectedError`, not to the client, and `BeakClient` reads that code as a
  `BeakInternalException`.

## Continue reading

- [The backend](https://simonerich.github.io/beak/backend/): running the server, databases, migrations and seeding.
- [Auth and policies](https://simonerich.github.io/beak/backend/auth-and-policies/): principals, roles and the rule set in depth.
- [Transactional business rules](https://simonerich.github.io/beak/backend/graph-business-rules/): `preparePlan`, `finalizePlan` and `graphOnly`.
- [REST API](https://simonerich.github.io/beak/reference/rest-api/): every route and its payloads.
- [Backend flow](https://simonerich.github.io/beak/architecture/backend-flow/): Handler, Service, DataSource.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
