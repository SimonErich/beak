---
title: The generated API
description: The generated REST surface for queries, graph saves, named actions, capabilities, validation, CRUD, export, uploads and health probes.
---

# The generated API

After this page you will know every endpoint a registered model gets, and where
those endpoints come from: two functions, `beakApiRouter` and
`beakResourceRouter`, that generate the whole surface from the registry.

Model routes and registry wiring are generated. A schema annotated with
`@Resource()` is discovered by `beak prepare` and added to the registry; the
router loop turns each registered model into a REST resource. This
page is the map of what that produces. For the exhaustive request and response
shapes, see the [REST API reference](../reference/rest-api.md).

## One function mounts everything

`beakApiRouter` is the top of the surface. It mounts the health probes, the auth
routes (when auth is configured), the global search endpoint, and one resource
router per registered model under `/api/{table}`, each with export and (when
storage is configured) upload routes.

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
Handler beakApiRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  ValidationService validation = const ValidationService(),
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakAuthSessions? auth,
  UploadService? uploads,
  BeakStorageDriver? storage,
  DateTime Function()? now,
  String Function()? generateId,
  BeakSavePlanPreparer? preparePlan,
  BeakSavePlanFinalizer? finalizePlan,
  Set<String> graphOnlyTables = const {},
}) {
```

`BeakServer` calls this for you, and the generated `BeakServeHost` constructs the
`BeakServer`. You only call it by hand to compose Beak inside a larger Shelf app,
and even then you wrap it in the [middleware](middleware.md) so typed exceptions
become HTTP/JSON.

!!! note "Hidden is a sidebar word, not an API word"
    Setting `hidden: true` for a table in `beak.yaml` keeps it out of the
    navigation. The model is still registered, so it still has every route below,
    and it is still reachable as the far side of a relationship. `order_items` in
    the shop is exactly that: no sidebar entry, full API subject to policy.

## The routes per model

`beakResourceRouter` builds one model's routes, relative to its `/api/{table}`
mount point. The tables below describe the resource and shared routes:

The resource router registers ordinary CRUD and query operations from the
registry. Capability and validation endpoints share the same model metadata;
transactional graph commits and named actions use the commit router.

For tables declared in `graphOnlyTables`, the mutation routes require a graph
commit and reject direct writes. Read routes stay available. See
[Transactional business rules](graph-business-rules.md) for the server hook.

Spelled out against the shop's `products` table (served on port 8080), that is:

| Method and path | What it does |
| --- | --- |
| `GET /api/products/capabilities` | Return field allowlists and authorized action names for create; `?id=<id>` resolves update capabilities for a visible row. Workflow availability is checked separately. |
| `POST /api/products/validate` | Preflight a `BeakValidationRequest` against shared model rules and record eligibility without saving. Returns field errors. |
| `POST /api/products/query` | Run a `BeakQuerySpec`: filter, sort, search, paginate, load relations. Returns a `BeakPage`. |
| `POST /api/products/aggregate` | Compute a `BeakAggregateSpec`: count, sum, or avg. Returns `{"value": ...}`. |
| `POST /api/products/batch` | Fetch the records named by `{"ids": [...]}` in one query. |
| `POST /api/products` | Create a record from a flat `{column: value}` body. Returns `201`. |
| `GET /api/products/<id>` | Fetch one record by id. |
| `PATCH /api/products/<id>` | Partially update a record. Honors `If-Unmodified-Since` and answers `409` when the row moved. |
| `DELETE /api/products/<id>` | Soft-delete a record. Append `?force=true` to hard-delete. Returns `204`. |
| `POST /api/products/<id>/restore` | Clear a soft-delete marker and return the record as it now reads. |
| `POST /api/products/<id>/relations/<relationKey>/attach` | Link related ids to a to-many relation. Returns `204`. |
| `POST /api/products/<id>/relations/<relationKey>/detach` | Unlink related ids. Returns `204`. |

Notice reads go through `POST /query`, not `GET` with a query string. A query is
a typed `BeakQuerySpec` in the body, not a pile of stringly-typed URL parameters.
That is how the same spec type travels from the panel's filters to the server
without anyone hand-parsing `?filter[price][gte]=10`.

`restore` is the one operation that deliberately reaches past the soft-delete
scope: the row is still there, and a deletion the user can walk back is the
difference between a panel people trust and one they are afraid of. It answers
`422` on a model that does not soft-delete at all, rather than reporting a
success it did not perform.

## The extra surfaces

On top of the per-model CRUD routes, `beakApiRouter` mounts a few more. Export
and upload attach to each model's router; search, auth, the probes and the local
file route sit at the top level.

| Method and path | Present when | What it does |
| --- | --- | --- |
| `POST /api/commits` | always | Submit a typed `BeakSavePlan`, including an optional named action and arguments. Returns per-operation outcomes. |
| `GET /api/commits/<saveId>` | always | Recover the caller's saved receipt with current authorization applied. |
| `POST /api/products/export` | always | Stream a CSV attachment for a posted `BeakQuerySpec`. |
| `POST /api/products/<columnKey>/upload` | `uploads` configured | Upload a file for a column. |
| `GET /api/products/<columnKey>/upload?key=<key>` | `uploads` configured | Resolve an existing upload URL after field, key and row-scope authorization. |
| `DELETE /api/products/<columnKey>/upload` | `uploads` configured | Remove an uploaded file. |
| `GET /api/search?q=...` | always | Global search across all policy-viewable models. Also takes `perModel` and `tables`. |
| `POST /api/auth/login` | `auth` configured | Exchange credentials for a session token. |
| `POST /api/auth/logout` | `auth` configured | End the session. |
| `GET /api/auth/me` | `auth` configured | Return the current principal. |
| `GET /healthz` | always | Liveness. Answers `200` as long as the process serves, without touching the database. |
| `GET /readyz` | always | Readiness. `200` when the data source answers, `503` with the cause when it does not. |
| `GET /uploads/<key>` | local-disk storage | Serve a file the local driver wrote, read-only. |

Named model actions use the graph commit endpoint rather than separate action
routes. Commit receipts distinguish applied, unapplied and unknown outcomes;
clients recover an uncertain save using its existing save ID before deciding
what to submit next. See [Graph saves](../reference/rest-api.md#graph-saves-and-recovery) and
[Transactional business rules](graph-business-rules.md).

The last three are mounted first and outside `/api`:

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
  // Outside `/api`, and mounted first: a platform's probes must not be
  // subject to the auth middleware that guards the API.
  router.mount(
    '/',
    beakHealthRouter(registry: registry, dataSource: dataSource).call,
  );
  // Files the local-disk driver wrote are served by this server, so an
  // upload's URL resolves with no CDN, bucket or proxy in front.
  if (storage case final BeakLocalDiskStorageDriver local) {
    router.mount('/', beakLocalUploadsRouter(local).call);
  }
```

A probe arrives with no credentials, so it must not pass through the auth
middleware. And the file route means uploads work on a laptop with no S3, no
MinIO and no reverse proxy: it serves the driver's root under the path of
`BEAK_LOCAL_PUBLIC_BASE_URL`, which is why the path in the table is `/uploads`
rather than something Beak chose. Point that variable at a CDN in production and
the route stops being used.

Export lives in [Search and export](search-and-export.md), uploads in
[Uploads and storage wiring](uploads-and-storage-wiring.md), and auth in
[Auth and policies](auth-and-policies.md).

## The handlers behind the routes are thin

Each route points at a method on `BeakCrudHandlers`. Those methods do four things
and no more: check the policy, parse the body into a typed record or spec, call
the service, and encode the result. The `query` handler is representative.

Query handling decodes the typed specification, authorizes requested paths,
applies row and field policy, and returns a page of readable records. Hidden
fields are not exposed through a different projection or relationship query.

No business logic, no `try/catch` for its own errors. Validation and defaults
live in the service below; error-to-HTTP mapping lives in the middleware above.
If a client posts a malformed spec, the handler lets the decode throw a
`BeakValidationException`, and the
[error-mapping middleware](middleware.md) turns it into a `422`.

!!! note "Every operation is gated twice"
    Each handler consults a `BeakPolicy` before it does anything (`_requireView`
    on reads, `canCreate`/`canUpdate`/`canDelete` on writes). It also reads the
    row scope once and hands it down:

    ```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
      BeakFilter? _scope(Request request) =>
          _authorizer(request).scopeFor(service.model.table);
    ```

    The scope is enforced in the service, not per route, so there is no endpoint
    left to forget. With the default `BeakAllowAllPolicy` there is no scope and
    everything passes. See [Auth and policies](auth-and-policies.md).

## Continue reading

- [REST API reference](../reference/rest-api.md) the full request and response shapes.
- [Middleware](middleware.md) the pipeline that wraps these routes.
- [The data source seam](the-data-source-seam.md) where the handlers' reads and writes
  land.
- [Running the server](running-the-server.md) the generated host that mounts this router.
- [How data flows](../concepts/how-data-flows.md) the `BeakQuerySpec` that `POST /query`
  accepts.
