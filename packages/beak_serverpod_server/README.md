# beak_serverpod_server

Runs Beak's admin API inside a Serverpod 4 server: one gated endpoint method,
Beak's stock Shelf pipeline in memory behind it, on the request's own Serverpod
database session. There is no second server, no second database and no endpoint
per table.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## When you need it

This is the server half of the admin app path. Serverpod keeps owning tables,
migrations, sign-in and scopes, and Beak adds the panel on top. You write, per
table, a pure Dart schema class that mirrors the `.spy.yaml` model (the
`<name>_beak` package), one endpoint, one engine and one policy.

The trade is stated up front: Beak writes rows directly through SQL on the
session, so logic that lives in your own endpoint methods (an audit row, a cache
flush, a webhook) does not run for admin writes. If your endpoints hold rules the
admin must not bypass, take the client bridge instead
([`beak_serverpod`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod)
and [`beak_serverpod_generator`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_generator)),
which changes nothing on the server.
[Choosing an integration](https://simonerich.github.io/beak/serverpod/choosing-an-integration/)
compares the two.

The panel side is
[`beak_serverpod_flutter`](https://github.com/SimonErich/beak/tree/main/packages/beak_serverpod_flutter).

## The endpoint, the engine, the policy

The endpoint is one method. `BeakAdminGate` is a getter-only mixin that puts
`requireLogin` and the `beak.admin` scope in front of it, so Serverpod answers
401 or 403 before any Beak code runs:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart"
/// The Beak admin tunnel: one method, gated by [BeakAdminGate] (a signed-in
/// user holding the `beak.admin` scope) before any Beak code runs.
class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
  /// Runs one Beak request (envelope v1) and returns the response envelope.
  Future<String> dispatch(Session session, String request) =>
      bookshopBeak.dispatch(session, request);
}
```

The engine is a top-level value, built once and shared by every request. `policy`
is required: there is no allow-all default.

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_beak_engine.dart"
/// The bookshop's Beak engine: one per process, shared by every request.
///
/// It serves Beak's stock API for the models in `bookshop_beak` on the
/// request's own Serverpod session, so every statement runs on Serverpod's
/// database with its transactions and logging.
final BeakServerpodEngine bookshopBeak = BeakServerpodEngine(
  registry: buildBeakRegistry(),
  policy: bookshopPolicy,
);
```

Holding `beak.admin` opens the tunnel and grants nothing. The policy names every
model and operation it allows, and everything else is closed:

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
```

The whole path, file by file, is
[Setting up the admin app](https://simonerich.github.io/beak/serverpod/admin-app/setup/).

## What one request does

`BeakServerpodEngine.dispatch(session, envelope)`:

1. Decodes envelope v1. A malformed one is a 400, and an unsupported version says
   which version the server speaks.
2. Turns the path into an internal URL with `beakTunnelUrl`, or answers 404. Only
   `/api/**` passes, never `/api/auth/**` (Serverpod owns sign-in), and
   percent-encoded dots, empty segments and separators are refused rather than
   resolved. Health probes and file routes are outside `/api` and refused too.
3. Drops every header but `content-type`, `accept`, `if-unmodified-since` and
   `x-beak-request-id`.
4. Resolves the principal from `session.authenticated` alone, and hands it to
   Beak's auth middleware through a context value only this library can create,
   so no header can forge an identity. The default resolver
   (`BeakServerpodPrincipal.fromScopes`) uses the user id and turns every scope
   name into a role, which is why `BeakAccess.role('bookshop.staff')` takes the
   scope's name.
5. Runs the pipeline inside `BeakServerpod.runInSession`, so every statement uses
   this request's session, pool and, in a graph commit, one Serverpod
   transaction.
6. Logs `beak <method> <path> -> <status>` to `session.log`, and unexpected
   errors as errors.

## Main types

| Type | What it is |
| --- | --- |
| `BeakServerpodEngine` | Beak's Shelf pipeline in memory. Takes `registry`, a required `policy`, and optional `principal`, `preparePlan`, `finalizePlan`, `graphOnly`, `statementTimeoutInSeconds` (30), `frameworkTables`, `now` and `adapter`. |
| `BeakAdminGate` | The mixin that requires a login and `BeakScopes.admin`. |
| `BeakScopes` | `BeakScopes.admin` is `Scope('beak.admin')`. It is deliberately not `Scope.admin`, so your own admins do not get the panel by accident. |
| `BeakServerpodPrincipal`, `BeakServerpodPrincipalResolver` | Turn the signed-in user into the `BeakPrincipal` your policy decides on. Return `null` to refuse with 403. |
| `ServerpodSessionAdapter` | A worm `DatabaseAdapter` over `session.db.unsafeQuery` and `unsafeExecute`. A nested transaction is a savepoint, never flattened. |
| `BeakServerpod` | The zone that carries the `Session` into Beak (`runInSession`), plus `sessionOf` and `transactionOf` to hand typed Serverpod ORM writes the same session and transaction. |
| `beakServerpodFrameworkTables` | Maps Beak's graph-commit receipts onto the Serverpod model `beak_commit_receipt` and its effect outbox onto `beak_outbox`. |
| `beakTunnelUrl` | The path filter of step 2. |
| `mapServerpodDatabaseException` | Turns Serverpod's database errors into the worm exceptions Beak's services catch: a unique violation reads as one whether it happens mid-transaction or at `COMMIT`. |

## Receipts and the server-only column

A form save is a graph commit, and a graph commit keeps a receipt so a retry is
safe. Serverpod's migrations own that table here, so the server carries a model
file copied verbatim from Beak (`serverOnly: true`, table `beak_commit_receipt`)
and the engine maps Beak's receipt columns onto it:

```yaml title="examples/serverpod/bookshop_server/lib/src/beak/models/beak_commit_receipt.spy.yaml"
class: BeakCommitReceipt
serverOnly: true
table: beak_commit_receipt
fields:
  ### (principal, saveId) namespace key.
  receiptKey: String, unique

  ### Hash of the submitted plan; a replay with another hash is rejected.
  requestHash: String

  ### The prepared plan, kept for recovery.
  requestJson: String

  ### The authoritative result (a pending marker while in flight).
  resultJson: String

  createdAt: DateTime, default=now
```

Beak's data source selects, returns and stores in receipts only the columns its
models declare, so a `SELECT *` never happens. A column that Serverpod keeps out
of the client (`scope=serverOnly`) and that the Beak schema class does not
declare never leaves the database.

## Limits

- The admin app is a proof on two tables, not a product. The example's tests
  cover the gate, the deny-by-default policy, reads and writes, the server-only
  column, commit replay, and the worm and Beak data-source contracts on
  `ServerpodSessionAdapter`.
- The schema classes are hand-written mirrors of the `.spy.yaml` models. The
  example's test compares column names and enum values, not types, nullability or
  uniqueness, and there is no runtime drift check.
- No uploads: the engine passes no storage to Beak's router, and the tunnel
  carries text only. The engine has no outbox parameter. `preparePlan`,
  `finalizePlan` and `graphOnly` are covered by this package's unit tests, and the
  example uses none of them.
- `ServerpodSessionAdapter` cannot create or change tables. `executeSchema` and
  `introspectSchema` throw `UnsupportedOperationException` and point at
  `serverpod create-migration`.
- The panel shares your app's process and pool. Each statement times out after
  30 seconds by default, and an export is built in memory and returned as one
  string.
- Every panel call is a Serverpod call, so the server's `maxRequestSize` caps it
  (512 KiB in the template). A larger request fails with 413.
- Revoking access is bounded by the access-token lifetime, 10 minutes by default.
- Requires Dart 3.12.2 and Serverpod `>=4.0.3 <5.0.0`. Only 4.0.3 is tested.
- Deployment is untested. The example's Docker build is not supported.

The unit tests here run against a fake `Session`. The tests that need a live
database are in the example.

## Continue reading

- [Setting up the admin app](https://simonerich.github.io/beak/serverpod/admin-app/setup/): build this, file by file.
- [How the admin app works](https://simonerich.github.io/beak/serverpod/admin-app/how-it-works/): one request from the panel to a row in Postgres.
- [Limits and next steps](https://simonerich.github.io/beak/serverpod/admin-app/limits-and-next-steps/): every gap, its reason and its workaround.
- [Authentication and scopes](https://simonerich.github.io/beak/serverpod/authentication/): granting and revoking `beak.admin`.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
