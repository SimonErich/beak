---
title: The generated API
description: The REST surface beakApiRouter and beakResourceRouter mint for every registered model: query, CRUD, batch, relations, aggregate, export, upload, and search.
---

# The generated API

After this page you will know every endpoint a registered model gets, and where those
endpoints come from: two functions, `beakApiRouter` and `beakResourceRouter`, that
generate the whole surface from the registry.

You do not write routes in Beak. You register models, and the router loop turns each one
into a REST resource. This page is the map of what that produces. For the exhaustive
request and response shapes, see the [REST API reference](../reference/rest-api.md).

## One function mounts everything

`beakApiRouter` is the top of the surface. It mounts the auth routes (when auth is
configured), the global search endpoint, and one resource router per registered model
under `/api/{table}`, each with export and (when storage is configured) upload routes.

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
Handler beakApiRouter({
  required BeakModelRegistry registry,
  required BeakDataSource dataSource,
  ValidationService validation = const ValidationService(),
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakAuthSessions? auth,
  UploadService? uploads,
  DateTime Function()? now,
  String Function()? generateId,
}) {
  // ...mounts /api/auth, GET /api/search, and per-model /api/{table}...
}
```

`BeakServer` calls this for you. You only call it by hand to compose Beak inside a
larger Shelf app, and even then you wrap it in the [middleware](middleware.md) so typed
exceptions become HTTP/JSON.

## The routes per model

`beakResourceRouter` builds one model's routes, relative to its `/api/{table}` mount
point. The list is short and complete:

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
return Router()
  ..post('/query', handlers.query)
  ..post('/aggregate', handlers.aggregate)
  ..post('/batch', handlers.batch)
  ..post('/', handlers.create)
  ..get('/<id>', handlers.getOne)
  ..patch('/<id>', handlers.update)
  ..delete('/<id>', handlers.delete)
  ..post('/<id>/relations/<relationKey>/attach', handlers.attach)
  ..post('/<id>/relations/<relationKey>/detach', handlers.detach);
```

Spelled out against the tutorial store's `products` table (served on port 8080), that
is:

| Method and path | What it does |
| --- | --- |
| `POST /api/products/query` | Run a `BeakQuerySpec`: filter, sort, search, paginate, load relations. Returns a `BeakPage`. |
| `POST /api/products/aggregate` | Compute a `BeakAggregateSpec`: count, sum, or avg. Returns `{"value": ...}`. |
| `POST /api/products/batch` | Fetch the records named by `{"ids": [...]}` in one query. |
| `POST /api/products` | Create a record from a flat `{column: value}` body. Returns `201`. |
| `GET /api/products/<id>` | Fetch one record by id. |
| `PATCH /api/products/<id>` | Partially update a record. |
| `DELETE /api/products/<id>` | Soft-delete a record. Append `?force=true` to hard-delete. Returns `204`. |
| `POST /api/products/<id>/relations/<relationKey>/attach` | Link related ids to a to-many relation. Returns `204`. |
| `POST /api/products/<id>/relations/<relationKey>/detach` | Unlink related ids. Returns `204`. |

Notice reads go through `POST /query`, not `GET` with a query string. A query is a typed
`BeakQuerySpec` in the body, not a pile of stringly-typed URL parameters. That is how the
same spec type travels from the panel's filters to the server without anyone hand-parsing
`?filter[price][gte]=10`.

## The extra surfaces

On top of the per-model CRUD routes, `beakApiRouter` mounts a few more. Export and upload
attach to each model's router; search and auth sit at the top level.

| Method and path | Present when | What it does |
| --- | --- | --- |
| `POST /api/products/export` | always | Stream a CSV attachment for a posted `BeakQuerySpec`. |
| `POST /api/products/<columnKey>/upload` | `storage` configured | Upload a file for a column. |
| `DELETE /api/products/<columnKey>/upload` | `storage` configured | Remove an uploaded file. |
| `GET /api/search?q=...` | always | Global search across all policy-viewable models. Also takes `perModel` and `tables`. |
| `POST /api/auth/login` | `auth` configured | Exchange credentials for a session token. |
| `POST /api/auth/logout` | `auth` configured | End the session. |
| `GET /api/auth/me` | `auth` configured | Return the current principal. |

Export lives in [Search and export](search-and-export.md), uploads in
[Uploads and storage wiring](uploads-and-storage-wiring.md), and auth in
[Auth and policies](auth-and-policies.md).

## The handlers behind the routes are thin

Each route points at a method on `BeakCrudHandlers`. Those methods do four things and no
more: check the policy, parse the body into a typed record or spec, call the service, and
encode the result. The `query` handler is representative.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
Future<Response> query(Request request) async {
  _requireView(request);
  final spec = readBeakSpec(
    await readJsonObject(request),
    BeakQuerySpec.fromJson,
  );
  final page = await service.query(spec);
  return _json(200, page.toJson((record) => record.toJson()));
}
```

No business logic, no `try/catch` for its own errors. Validation and defaults live in the
service below; error-to-HTTP mapping lives in the middleware above. If a client posts a
malformed spec, the handler lets the decode throw a `BeakValidationException`, and the
[error-mapping middleware](middleware.md) turns it into a `422`.

!!! note "Every operation is gated"
    Each handler consults a `BeakPolicy` before it does anything (`_requireView` on
    reads, `canCreate`/`canUpdate`/`canDelete` on writes). With the default
    `BeakAllowAllPolicy` everything passes; supply a real policy to lock the surface
    down. See [Auth and policies](auth-and-policies.md).

## Continue reading

- [REST API reference](../reference/rest-api.md) the full request and response shapes.
- [Middleware](middleware.md) the pipeline that wraps these routes.
- [The data source seam](the-data-source-seam.md) where the handlers' reads and writes
  land.
- [How data flows](../concepts/how-data-flows.md) the `BeakQuerySpec` that `POST /query`
  accepts.
