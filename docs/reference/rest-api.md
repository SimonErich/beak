---
title: REST API
description: Look up every endpoint the backend generates, with request bodies, responses and the error envelope.
type: reference
audience: [expert, agent]
status: draft
search: {boost: 2}
---

# REST API

After this page you can call a Beak backend by hand: the exact path, method,
request body, response shape, and status code of every route Beak generates, plus
the error envelope every failure comes back in.

You rarely write these calls yourself. The panel talks to this surface through
`HttpBeakDataSource`, and the typed `BeakClient` in `beak_core` wraps every route
below. This page is the contract underneath both, for when you reach for `curl`,
write an integration test, or point another client at the server.

## How the surface is assembled

`beakApiRouter` mounts one resource router per registered model under
`/api/{table}`, plus the global search route, the health probes, and (when
configured) the auth surface. Declaring a resource is all it takes to get its
routes: nothing here is hand-written or generated into your project.

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/beak_resource_router.dart:beakResourceRouter"
```

`registerExportRoutes` adds `POST /export` to each resource router, and
`registerUploadRoutes` adds upload, URL lookup and deletion routes when the server has storage
wired. Everything below lives under those mounts.

!!! note "What just happened"
    - The route table is derived from your registry, not hand-written. Two models
      means two identical surfaces under two table prefixes.
    - Every handler consults a [policy](../backend/auth-and-policies.md) before it
      touches data, and the [error-mapping middleware](../backend/middleware.md)
      turns any typed failure into the JSON envelope described at the end of this
      page.

## Conventions

These hold for every route on the page. Request bodies below are illustrative
for a product resource served on port `8080`; available columns, required values
and graph-only writes depend on the registered model. The maintained shop uses
`examples/clean_beak_config` and includes business rules beyond these minimal
request examples.

| Convention | Detail |
| --- | --- |
| Base path | Every route is under `/api`, except the `/healthz` and `/readyz` probes and the local-disk upload route. Resource routes are under `/api/{table}`, where `{table}` is what `@Resource(table:)` says or what Beak derived from the class name. |
| Request bodies | JSON objects. `POST`/`PATCH` bodies are read with `readJsonObject`: a body that is not valid JSON, or not a JSON object, is a `422`. |
| Spec bodies | A query spec needs only `table`; an aggregate spec needs `table` and `function`. Every other key falls back to its default, so `{"table": "products"}` is a valid query. Responses still carry every key. |
| Response bodies | JSON, `content-type: application/json; charset=utf-8` (set by the JSON middleware). Exports and file downloads carry their own content type. |
| Auth header | `Authorization: Bearer <token>` when the server has an auth guard installed. A missing or invalid token is anonymous, not an error, until a policy denies the action. |
| Request id | Every response echoes `x-request-id` (reusing an incoming one), and error bodies carry the same value as `requestId`. |
| Ids in paths | The `<id>` segment is coerced to the model's primary-key type. For an integer key, a non-integer id is a `404`, never a crash. |

## Graph saves and recovery

Configured forms use `BeakClient.commit(BeakSavePlan)` and
`recoverCommit(saveId)` through the source capability seam. The plan and result
have typed `toJson`/`fromJson` contracts; callers do not need to handcraft JSON.

A `200` commit response means the outcome was evaluated. Inspect
`BeakSaveResult.complete`, `mode`, and each operation's status before reporting
success. An atomic validation failure returns unapplied outcomes and leaves the
graph unchanged. A durable successful receipt is written with the data and is
returned on repeated submission of the same save id. Reusing a save id for a
different plan is rejected. Receipt lookup is scoped to the authenticated
principal and performs no write.

The server validates model rules, permissions, references, and child membership
for the complete graph. Owned deletion additionally requires explicit ownership
metadata. [Declarative resources and forms](../concepts/declarative-resources.md)
explains the staged fallback used by other sources and handling of unknown
outcomes after transport failure.

## Validation and field capabilities

`GET /api/{table}/capabilities?id=<id>` resolves field read/write access for the
current principal, with `readableFields`, `writableFields` and
`executableActions` allowlists. Action permissions combine resource create/update
access, `BeakActionPolicy` and `allowOnCreate`; workflow availability is evaluated
separately. The optional id selects an existing record and is checked
against the row scope before capabilities are returned. It is presentation
metadata: the backend still authorizes every request independently.

`POST /api/{table}/validate` accepts the JSON form of
`BeakValidationRequest.forModel(model, record, recordId: id)`. It evaluates
server-declared asynchronous rules, such as uniqueness and relationship
eligibility, without writing. A `200` report contains `fieldErrors`, an empty
map when those checks pass. Invalid request shapes and denied access remain
HTTP errors. Synchronous model rules and complete graph invariants still run
on save; preflight does not reserve a unique value or replace a database
constraint.

## Route map

| Method | Path | Purpose | Success |
| --- | --- | --- | --- |
| `POST` | `/api/commits` | Submit a typed graph save plan | `200` with per-operation outcomes |
| `GET` | `/api/commits/<saveId>` | Recover the caller’s durable save receipt | `200` |
| `GET` | `/api/{table}/capabilities` | Read principal-specific field capabilities | `200` |
| `POST` | `/api/{table}/validate` | Preflight a candidate record without saving | `200` with field errors |
| `POST` | `/api/{table}/query` | Run a `BeakQuerySpec`, get a page of records | `200` |
| `POST` | `/api/{table}/aggregate` | Compute a `BeakAggregateSpec` (count/sum/avg) | `200` |
| `POST` | `/api/{table}/batch` | Fetch many records by id in one call | `200` |
| `POST` | `/api/{table}` | Create a record | `201` |
| `GET` | `/api/{table}/<id>` | Fetch one record | `200` |
| `PATCH` | `/api/{table}/<id>` | Partially update a record | `200` |
| `DELETE` | `/api/{table}/<id>` | Soft-delete (or force-delete) a record | `204` |
| `POST` | `/api/{table}/<id>/restore` | Clear a record's soft-delete marker | `200` |
| `POST` | `/api/{table}/<id>/relations/<relationKey>/attach` | Link related ids | `204` |
| `POST` | `/api/{table}/<id>/relations/<relationKey>/detach` | Unlink related ids | `204` |
| `POST` | `/api/{table}/export` | Stream matching rows as CSV | `200` |
| `POST` | `/api/{table}/<columnKey>/upload` | Store a file for a file/image column | `201` |
| `GET` | `/api/{table}/<columnKey>/upload?key=<key>` | Resolve an authorized existing upload URL | `200` |
| `DELETE` | `/api/{table}/<columnKey>/upload` | Remove a stored file | `204` |
| `GET` | `/api/search` | Global search across viewable models | `200` |
| `POST` | `/api/auth/login` | Exchange credentials for a session token | `200` |
| `POST` | `/api/auth/logout` | Revoke the presented token | `204` |
| `GET` | `/api/auth/me` | The authenticated principal | `200` |
| `GET` | `/healthz` | Liveness: is the process serving? | `200` |
| `GET` | `/readyz` | Readiness: does the data source answer? | `200` / `503` |

The upload routes exist only when the server is built with an `UploadService`
(storage wired); the auth routes only when it is built with `BeakAuthSessions`.
Graph commit routes are mounted for `WormDataSource` and require the commit
receipt migration. The per-resource data routes are present for every registered
model. Models with lifecycle behavior and tables configured for graph-only
writes reject direct mutations; save them through `/api/commits` so their
transactional rules and named actions run.

One more route appears with the local-disk storage driver: a read-only `GET`
under the path of its `publicBaseUrl` (`/uploads/<key>` by default), serving the
files that driver wrote. It exists so `beak create` gives you working uploads
with no S3, no MinIO and no reverse proxy. Point
`BEAK_LOCAL_PUBLIC_BASE_URL` at a CDN and the route stops being used. A key that
climbs out of the driver's root is a `404`, not a file.

The two probes sit **outside `/api`** on purpose: a container platform's probe
arrives with no credentials, so it must not pass through the auth middleware.
`/healthz` never touches the database, because a liveness probe decides whether
to *restart* the process and a database blip must move traffic away rather than
kill it. `/readyz` is the one that answers `503`, with the cause:

```json
{"status": "unavailable", "detail": "connection refused"}
```

## Conditional updates

`PATCH` honours `If-Unmodified-Since` against the record's stored `updated_at`
and answers `409 Conflict` when it has moved:

```bash
curl -X PATCH localhost:8080/api/products/p1 \
  -H 'content-type: application/json' \
  -H 'if-unmodified-since: 2026-07-26T20:24:56.910652Z' \
  -d '{"name": "Chisel v2"}'
```

It is opt-in: a request without the header updates unconditionally, which is
suitable only when the caller accepts last-write-wins behavior. Two concurrent
editors should carry an explicit concurrency baseline. This header applies to
the direct PATCH route; graph commit receipts provide idempotent recovery, not
an automatic optimistic-locking guarantee.

An unparseable header is a `422`, never a silent unconditional write.

## Row-level scoping

A `BeakPolicy` answers "may this principal read orders". That is not the same
question as "may they read *these* orders", and a filter in a query spec comes
from the client, so a policy meaning "a customer sees only their own" is
bypassed by asking for everything.

Implement `BeakRowPolicy` instead and its `scopeFor(principal, table)` filter is
intersected with **every** read and write of that table: query, aggregate,
get-one, batch, update, delete, attach, detach, restore, CSV export and global
search. It is enforced in the service layer rather than per endpoint, so there
is no route left to forget.

A record outside the scope reports as `404`, not `403`: telling an
unauthorised caller that a record exists is itself a leak.

## Wire types

Two shapes recur across the routes below, so they are worth naming once.

### The record

A record is `{ "values": {...}, "relations": {...} }`. `values` maps a column key
to its JSON value; `relations` maps a relation key to a list of nested records
(only the relations the query eager-loaded appear).

```dart title="packages/beak_core/lib/src/query/beak_record.dart"
--8<-- "packages/beak_core/lib/src/query/beak_record.dart:toJson"
```

Values encode as their raw JSON primitive (string, number, bool, `null`) or array.
The one exception is a timestamp, which is tagged so decoding never mistakes it for
a plain string:

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
final class BeakDateTimeValue extends BeakValue {
  // ...
  @override
  Object? toJson() => {'type': 'dateTime', 'value': value.toIso8601String()};
  // ...
}
```

So a product record on the wire looks like:

```json
{
  "values": {
    "id": "p1",
    "name": "Ethiopia Yirgacheffe",
    "sku": "ETH-YIR-250",
    "price": 18.5,
    "stock": 42,
    "featured": true,
    "status": "published",
    "category_id": "c1",
    "created_at": { "type": "dateTime", "value": "2026-07-24T09:00:00.000Z" }
  },
  "relations": {
    "tags": [
      { "values": { "id": "t3", "name": "single-origin" }, "relations": {} }
    ]
  }
}
```

An enum column travels as the value's `name`, and a relationship's foreign key
travels as an ordinary column value (`category_id`). The related record itself
appears under `relations` only when the query eager-loaded it.

### The page envelope

`POST /query` returns records inside a paging envelope. It is generic over the
item type and carries no `dynamic`.

```dart title="packages/beak_core/lib/src/query/beak_page.dart"
--8<-- "packages/beak_core/lib/src/query/beak_page.dart:toJson"
```

`total` is the count across all pages; `page` is 1-based; `perPage` is the page
size the query used. `page * perPage < total` tells a client there is more to
fetch.

## Resource routes

### Query records

`POST /api/{table}/query` runs a posted `BeakQuerySpec` and returns a page of
records.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:query"
```

The request body is a serialized `BeakQuerySpec`. Every top-level key is
optional except `table`; a malformed spec is a `422`, not a `500`.

```json
{
  "table": "products",
  "filter": {
    "type": "field",
    "column": "status",
    "operator": "eq",
    "value": "published"
  },
  "sorts": [{ "column": "created_at", "descending": true }],
  "search": { "term": "espresso", "columns": ["name"] },
  "relations": [{ "relation": "category", "filter": null, "nested": [] }],
  "pagination": { "page": 2, "perPage": 50 },
  "withTrashed": false
}
```

Eager loads live under `relations`, and each one is an **object keyed
`relation`**, not a bare relation name. Unlike the top-level keys, a relation
load spells all three of its own out: `filter` narrows which related rows load
(`null` for all of them) and `nested` eager-loads the related model's own
relations. Beak never lazy-loads, so a relation the spec does not name is absent
from the response.

The `filter` node is a predicate tree. A leaf is
`{ "type": "field", "column": <key>, "operator": <name>, "value": <value> }`;
branches are `{ "type": "and", "filters": [...] }` and its `or` sibling. The
`operator` name is a `BeakOperator` (`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `like`,
`ilike`, `contains`, `startsWith`, `endsWith`, `isNull`, `isNotNull`, `inList`,
`notInList`, `between`, `notBetween`). The response is a page envelope of records
(`200`).

### Aggregate

`POST /api/{table}/aggregate` computes a single number.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:aggregate"
```

The body is a serialized `BeakAggregateSpec`. `function` is `count`, `sum`, or
`avg`; `column` is required for `sum` and `avg` and must be absent for `count`.

```json
{ "table": "products", "function": "avg", "column": "price", "filter": null, "withTrashed": false }
```

The response is `{ "value": <number> }` (`200`).

### Create

`POST /api/{table}` creates a record from a flat body of column values (not the
`{values, relations}` record envelope).

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:create"
```

```json
{ "name": "Ethiopia Yirgacheffe", "sku": "ETH-YIR-250", "price": 18.5, "stock": 42 }
```

The response is the created record (`201`), with the server-assigned id in
`values`. Values that violate the model's [validation rules](validation-rules.md)
come back as a `422` with per-field messages; a value the record layer cannot
parse is a `422` as well.

### Fetch one

`GET /api/{table}/<id>` returns one record (`200`) or a `404` when nothing
matches.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:getOne"
```

### Update

`PATCH /api/{table}/<id>` partially updates a record. The body is a flat map of
only the columns you want to change; omitted columns keep their value.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:update"
```

The response is the updated record (`200`).

### Delete

`DELETE /api/{table}/<id>` soft-deletes the record on models that support it. Add
`?force=true` to delete for real.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:delete"
```

The response has no body (`204`). Soft deletes come from
`@Resource(softDeletes: true)`, which adds the `deleted_at` marker; without it,
every delete is permanent.

### Restore

`POST /api/{table}/<id>/restore` clears a soft-delete marker and returns the
restored record (`200`). It is gated by `canUpdate`, not `canDelete`: bringing a
record back is not the inverse permission of removing it. Find the deleted rows
first by posting a query spec with `"withTrashed": true`.

### Batch fetch

`POST /api/{table}/batch` fetches many records by id in one query. The body is
`{ "ids": [...] }`; ids may be integers or strings.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:batch"
```

```json
{ "ids": ["p1", "p2", "p7"] }
```

The response is a JSON array of records (`200`). A body without an `ids` list, or
an id that is neither an integer nor a string, is a `422`.

### Attach and detach relations

For a to-many relation, `POST /api/{table}/<id>/relations/<relationKey>/attach`
links related ids and the `.../detach` route unlinks them. Both take
`{ "ids": [...] }` and return `204`.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/crud_handlers.dart:attach"
```

Both are gated by the `canUpdate` policy for the owning record: changing a
record's links counts as updating it.

## Export

`POST /api/{table}/export` streams the rows matching a `BeakQuerySpec` as a CSV
attachment.

The optional `columns` body property is a non-empty, unique list of scalar
model field names in export order. Unknown fields are rejected; unreadable
fields are omitted according to the current field policy. Omitting `columns`
retains the model's table-context projection. An optional `formats` object maps
selected field names to `{format, minorUnits, scale}` overrides. Format names
come from `BeakValueFormat`; scales must be integers from 0 through 12.
Overrides do not bypass field authorization or password redaction, and cannot
be combined with `raw: true`.

```dart title="packages/beak_backend/lib/src/export/export_router.dart"
--8<-- "packages/beak_backend/lib/src/export/export_router.dart:export"
```

The body is the same `BeakQuerySpec` you would post to `/query`, so the filters,
sorts, and search that shape the table shape the export too. The response is CSV
text (`200`) with a `content-disposition` attachment named after the table, gated
by `canView`.

## Uploads

Present only when the server has storage wired. The routes live under the column,
so a file targets exactly one file or image column of the model.

```dart title="packages/beak_backend/lib/src/uploads/upload_router.dart"
  router
    ..post('/<columnKey>/upload', handlers.upload)
    ..get('/<columnKey>/upload', handlers.url)
    ..delete('/<columnKey>/upload', handlers.remove);
```

`POST /api/{table}/<columnKey>/upload` takes a `multipart/form-data` body with the
file under the field name `file`. The handler bounds the read at the column's size
limit before buffering, so an oversize file never fills memory.

```dart title="packages/beak_backend/lib/src/uploads/upload_handler.dart"
--8<-- "packages/beak_backend/lib/src/uploads/upload_handler.dart:upload"
```

The response is a stored-file description (`201`):

```json
{
  "key": "products/image/p1-a1b2c3.webp",
  "url": "http://localhost:8080/uploads/products/image/p1-a1b2c3.webp",
  "sizeInBytes": 84213,
  "mimeType": "image/webp",
  "widthInPixels": 1200,
  "heightInPixels": 800,
  "variants": {
    "thumbnail": { "key": "...", "url": "...", "widthInPixels": 200, "heightInPixels": 133 }
  }
}
```

A body missing the `file` field is a `422`; a file over the column's
`maxSizeInBytes` is a `422` with `fieldErrors.size`. `DELETE
/api/{table}/<columnKey>/upload` removes a stored file named by `{ "key": ... }`
in the body and returns `204`, gated by `canDeleteUpload`.

## Global search

`GET /api/search` searches every model the caller may view and groups the hits by
table.

```dart
  Future<Response> search(Request request) async {
    final String term = request.url.queryParameters['q'] ?? '';
    if (term.trim().isEmpty) {
      throw const BeakValidationException(
        'The query parameter "q" is required.',
      );
    }
```

| Query parameter | Required | Default | Meaning |
| --- | --- | --- | --- |
| `q` | yes | none | The search term. An empty `q` is a `422`. |
| `perModel` | no | `5` | Max hits per model. Must be a positive integer. |
| `tables` | no | all viewable | Comma-separated table names to restrict the search to. |

The response groups `BeakSearchHit`s by table:

```json
{
  "results": {
    "products": [
      { "table": "products", "id": "p1", "displayLabel": "Ethiopia Yirgacheffe", "matchedColumnKey": "name" }
    ]
  }
}
```

`displayLabel` is the record's `@Display()` field, and `matchedColumnKey` names
the `@Column(searchable: true)` column that matched. Tables the caller cannot
view are filtered out before the search runs, and a row scope narrows what is
left, so search never leaks the existence of a hidden record.

## Auth

Present only when the server is built with `BeakAuthSessions`. The three routes are
mounted under `/api/auth`.

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
--8<-- "packages/beak_backend/lib/src/auth/auth_router.dart:beakAuthRouter"
```

`POST /api/auth/login` takes `{ "username": ..., "password": ... }`, verifies the
credentials against the configured accounts, and mints an opaque session token.

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
    final String token = await sessions.store.createSession(account.principal);
    return Response.ok(
      jsonEncode({'token': token, 'principal': account.principal.toJson()}),
    );
```

```json
{ "token": "b3f1…", "principal": { "id": "admin", "roles": ["admin"] } }
```

Wrong or unknown credentials are a `401` (`authentication`). `POST
/api/auth/logout` revokes the presented `Bearer` token and returns `204`. `GET
/api/auth/me` returns the authenticated principal (`{ "id": ..., "roles": [...] }`,
`200`), or a `401` when the request is anonymous. Pass the token from login as
`Authorization: Bearer <token>` on every authenticated request.

## The error envelope

Every failure comes back as the same JSON object. The error-mapping middleware is
the single catch boundary: it maps the sealed `BeakException` family to a status
code, and anything untyped to an opaque `500` so server internals never reach the
client.

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
  final int statusCode = switch (exception) {
    BeakValidationException() => 422,
    BeakNotFoundException() => 404,
    BeakAuthenticationException() => 401,
    BeakAuthorizationException() => 403,
    BeakConflictException() => 409,
    BeakConfigurationException() => 500,
    BeakStorageException() => 500,
  };
```

The body carries a stable `code`, a human `message`, an optional `fieldErrors`
map (only on validation failures with per-field messages), and the `requestId`
when the request-log middleware is installed.

```json
{
  "code": "validation",
  "message": "The product could not be saved.",
  "fieldErrors": { "price": ["Must be greater than 0"] },
  "requestId": "9f2c1a7b3e0d4a51"
}
```

| `code` | Status | Raised when |
| --- | --- | --- |
| `validation` | `422` | User input violates a rule, is malformed, or an upload is too large. Carries `fieldErrors`. |
| `not_found` | `404` | The record, route, or id does not exist. |
| `authentication` | `401` | Credentials are missing, invalid, or expired. |
| `authorization` | `403` | A policy denied an otherwise valid request. |
| `conflict` | `409` | The operation clashes with existing state (duplicate unique value, concurrent edit). |
| `configuration` | `500` | Beak itself is set up wrong (unregistered model, duplicate key). A developer error. |
| `storage` | `500` | A storage driver failed to store, read, or delete a file. |
| `internal` | `500` | Any untyped error. The body is always `{"code":"internal","message":"Internal server error."}`. |

Client libraries switch on `code`, never on the status, to rebuild the typed
exception. That is exactly what `BeakClient` does, so a `422` from the server
surfaces as a `BeakValidationException` with its `fieldErrors` intact.

## Continue reading

- [The generated API](rest-api.md) the same surface from the server's point of view, and how to compose it.
- [Auth and policies](../backend/auth-and-policies.md) how a policy turns into the `401`/`403` you see above.
- [Search and export](../backend/search-and-export.md) the services behind `/api/search` and `/export`.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) what the upload routes store and where.
- [Exceptions](exceptions.md) the full `BeakException` family behind the error envelope.
- [Configuration options](configuration.md) the env vars and config objects that stand this server up.


## Resolving and discarding uploads

`GET /api/{table}/{column}/upload?key={storageKey}` returns `{"url":"..."}`
for an existing key belonging to that upload column. It enforces the resource read
policy and uses the configured driver's public/signed URL. When the table has a
row scope, the key must be referenced by a record visible under that scope in the
requested upload column. Hidden and unreferenced keys both return `404`.
`BeakUploadReadPolicy.canViewUpload` can add key-specific restrictions. Standalone
upload routes need a data source to enforce row scopes and fail closed without one.
Invalid column paths and traversal are rejected before the driver is called.

Local disk file URLs and public buckets remain public: lookup authorization does
not restrict subsequent access to a public URL. Confidential media requires a
private storage driver that returns signed, expiring URLs.

`DELETE /api/{table}/{column}/upload` accepts `{"key":"..."}` and checks
`canDeleteUpload` for that exact key. The managed client discards each generated
rendition and original, treating an already missing file as cleaned up. It only
uses this for new draft-owned uploads known not to have committed.
