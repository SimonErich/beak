# Beak architecture

Beak turns **one model definition** into a running admin panel: the same typed
columns drive the table cell, the form input (with client-side validation that
mirrors the server byte-for-byte), the detail row, the filter, the REST
validation, and the CSV export column. This document explains how the pieces
fit so you know where a change belongs.

## The one-definition promise

A column is declared once, as a typed constant:

```dart
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name', label: 'Name',
    searchable: true, sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price', label: 'Price', prefix: '€', rules: [BeakMin(0)],
  );
  static const List<BeakColumn> values = [name, price];
}
```

From that single declaration:

- **beak_frontend** renders the table cell (`renderBeakCell` maps the column's
  render intent to an obers_ui widget) and the form field (`BeakFormController`
  bridges the column to `obers_ui_autoforms`, mirroring each `BeakRule` as a
  client validator with the *same* message the server produces).
- **beak_backend** validates writes against the same rules (`ValidationService`)
  and exports the column under its label (`CsvExportService`).
- **beak_core** carries the column in the serializable `BeakQuerySpec` that
  travels between the two.

Users never write a string field reference and never touch `dynamic`. That is
the invariant every API in the repo must preserve.

## Package graph

```
                         ┌───────────────────────────┐
      apps/reference_admin (Flutter)      apps/reference_admin_server (Shelf)
                         └──────────────┬────────────┘
                                        │  (both depend on shared models)
                          apps/reference_admin_models
                                        │
        ┌───────────────┬──────────────┼───────────────┬───────────────┐
   beak_frontend    beak_cli       beak_backend   beak_storage_s3   beak_image
        │                              │            beak_storage_ftp     │
        └──────────────┬───────────────┴───────────────┴────────────────┘
                       ▼
                   beak_core   ◀── the shared contract: columns, rules,
                       │            relationships, BeakQuerySpec, BeakValue,
                       ▼            storage abstraction, BeakDataSource, BeakClient
              packages/worm*   ◀── vendored ORM, used only by beak_backend
```

- **beak_core** is pure Dart and depends on nothing Beak-specific. It defines
  the vocabulary both sides share.
- **beak_backend** is the only package that imports `worm`. The rest of Beak
  never sees an ORM type.
- **beak_frontend** is the only Flutter package in the framework; it depends on
  `obers_ui` (path dependency) and never on `dart:io`/Shelf.

## Backend flow: `Handler → Service → DataSource`

```
HTTP request
   │
   ▼
Middleware  (request-id, CORS, JSON, auth)     ← error-mapping middleware is the
   │                                              catch boundary: it turns any
   ▼                                              BeakException into the right
Handler  (BeakCrudHandlers)  ── parse & route ── HTTP status + JSON envelope
   │      • policy check (BeakPolicy)
   │      • decode body → typed BeakRecord / BeakQuerySpec
   ▼
Service  (BeakResourceService)  ── logic ──────  throws typed BeakExceptions
   │      • mint uuid ids, stamp created_at/updated_at
   │      • validation (ValidationService)
   │      • relation-kind gating
   ▼
DataSource  (WormDataSource)  ── raw I/O ──────  lets exceptions propagate
   │      • WormQueryTranslator: BeakQuerySpec → worm predicate tree
   ▼
worm → Postgres / in-memory
```

Rules of the layers:

- **Handlers** only parse, authorize, and route. They never contain business
  logic. Malformed input is mapped to `422`, never `500`.
- **Services** own the logic and throw typed exceptions
  (`BeakValidationException`, `BeakNotFoundException`, …). They never touch
  Shelf types.
- **DataSources** do raw I/O and let exceptions propagate. `WormDataSource` is
  the default; it implements the `BeakDataSource` interface from beak_core.
- The **error-mapping middleware** is the single catch boundary. It maps the
  sealed `BeakException` family to status codes (`422/404/403/401/409/500`) and
  a `{code, message, fieldErrors, requestId}` body, and turns anything else into
  an opaque `500`.

The whole REST surface is **generated** from a `BeakModelRegistry`:
`beakApiRouter` mounts one resource router per model under `/api/{table}`, with
CRUD, query, batch, relations, aggregate, upload, search, and export endpoints —
no hand-written endpoints.

## Frontend flow: `Widget → ViewModel → Repository → DataSource`

```
Widget  (HookWidget)          renders signals, forwards intent — never try/catch
   │        e.g. BeakDataTable, BeakDataForm
   ▼
ViewModel                     exposes ReadonlySignals, owns the BeakQuerySpec
   │        e.g. TableViewModel, FormViewModel        — never try/catch
   ▼
Repository  (BeakResourceRepository)   the catch boundary — returns BeakResult<T>
   │
   ▼
DataSource  (HttpBeakDataSource → BeakClient)   HTTP to the generated API
```

Rules of the layers:

- **Widgets** are `HookWidget`s. State is [Signals]; a widget rebuilds from a
  `ReadonlySignal` and forwards user intent to its ViewModel.
- **ViewModels** expose only `ReadonlySignal`s and never `try/catch`. They
  translate intent into `BeakQuerySpec` changes and call the repository.
- **Repositories** are the catch boundary: every call returns a
  `BeakResult<T>` (`BeakOk` / `BeakErr`) so failures are values, not thrown
  exceptions, by the time they reach a ViewModel.
- UI is **obers_ui only** — no Material/Cupertino. DI is GetIt, routing is
  go_router.

## The `BeakDataSource` seam

`BeakDataSource` (in beak_core) is the interface every data operation goes
through — `query`, `getOne`, `create`, `update`, `delete`, `batchGet`,
`attach`/`detach`, and `aggregate`. It speaks only in beak_core types
(`BeakQuerySpec`, `BeakRecord`, `BeakPage`, `BeakAggregateSpec`).

Two implementations exist today:

- `WormDataSource` (beak_backend) — the server-side default, over the worm ORM.
- `HttpBeakDataSource` (beak_frontend) — the client-side implementation, over
  `BeakClient`'s REST calls.

Because the seam speaks only beak_core types, a future `beak_serverpod` package
can add a `ServerpodDataSource` **without changing beak_core or beak_backend**.
Keep worm and obers types from leaking across this boundary.

## The serializable query contract

`BeakQuerySpec` is the wire contract between the panel and the server: a fully
serializable description of a query — filters (a sealed `BeakFilter` tree),
sorts, search, pagination, relation loads, and soft-delete scope. Values travel
as the sealed `BeakValue` family (primitives raw; `DateTime` as a tagged
object), so a `POST /api/{table}/query` body round-trips losslessly. The
frontend builds a spec with immutable copy-builders (`withFilter`, `orderBy`,
`paginate`, `searching`, `withRelation`); `WormQueryTranslator` turns it into a
worm predicate tree on the server.

## Storage drivers

File columns validate and store through a pluggable driver system. A
`BeakStorageConfig` (sealed: memory / local / S3 / FTP) is resolved to a
`BeakStorageDriver` via a registry; drivers live in their own packages
(`beak_storage_s3`, `beak_storage_ftp`) behind thin seams (`S3ObjectClient`,
`FtpTransport`) so their logic is unit-testable against fakes. Uploads are
validated (size, MIME/type, image dimensions, aspect ratio) by the shared
`BeakUploadValidator` — the **same** validator the client runs before upload —
and image columns run a `BeakImageTransform` pipeline (resize, re-encode,
thumbnails) via `beak_image`. Storage keys are validated to reject path
traversal, absolute paths, and backslashes.

## Where to look

| I want to change…                    | Look in…                                    |
| ------------------------------------ | ------------------------------------------- |
| a column/rule/relationship type      | `beak_core/lib/src/columns`, `rules`, `relations` |
| the query wire format                | `beak_core/lib/src/query`                   |
| how a cell/form field renders        | `beak_frontend/lib/src/table`, `form`       |
| a generated endpoint                 | `beak_backend/lib/src/endpoints`, `service` |
| query → SQL translation              | `beak_backend/lib/src/data`                 |
| auth / policy                        | `beak_backend/lib/src/auth`                 |
| a storage driver                     | `beak_storage_s3`, `beak_storage_ftp`, `beak_image` |
| scaffolding commands                 | `beak_cli`                                  |

See each package's `README.md` for its public API and a usage snippet, and
`CONTRIBUTING.md` for the full guardrails.

[Signals]: https://pub.dev/packages/signals
