---
title: REST API
description: Every route the Beak backend generates, with method, path, body, response, policy gate and status codes, checked against a running server.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# REST API

A registered model gets the same set of routes under `/api/{table}`. Beyond those there are the graph-commit routes, the auth routes, two health probes and, for the local-disk storage driver, a read-only file route. This page lists each one with its request, response, policy gate and failure statuses. Transcripts were captured from a running quickstart server (the `notes` resource, in-memory SQLite) and, for uploads, the shop example; ids and timestamps differ on every run. The login, `401` and closed-route transcripts come from the same quickstart resource served with a `BeakAuthSessions` and `graphOnly: [NoteModel()]`.

## Import

You rarely call these routes by hand. The panel talks to them through `HttpBeakDataSource`, which wraps `BeakClient`. `BeakClient` has a method for every resource, commit, upload, export and login or logout route below.

```dart
import 'package:beak/beak.dart'; // BeakClient, BeakSavePlan, BeakSaveResult, BeakQuerySpec, BeakException
import 'package:beak/server.dart'; // beakApiRouter, BeakServer, BeakServeHost, BeakAuthSessions
```

`BeakServer` (built by the generated `beakHost()`) mounts everything on this page. `beakApiRouter` is the router on its own, for embedding Beak in a larger Shelf app.

## Summary

`{table}` is the model's stored table name, `{id}` its primary key, `{columnKey}` a file or image column. The Gate column names the `BeakPolicy` hooks the handler calls first. "Row scope" is the `BeakRowPolicy.scopeFor` filter (or `rowScope` of `BeakModelRules`), which is added to every read and write of the table. "Field access" is `BeakFieldPolicy` read or write access per column. See [Auth and policies](../backend/auth-and-policies.md).

| Method | Path | Purpose | Gate | Success | Mounted when |
| --- | --- | --- | --- | --- | --- |
| `POST` | `/api/commits` | Run a graph save plan | Per operation: field write access, `canCreate` / `canUpdate` / `canDelete`, owner `canUpdate`, row scope | `200` receipt | always |
| `GET` | `/api/commits/{saveId}` | Read a stored receipt | `canView` on every table of the plan, row scope on applied records | `200` receipt | always |
| `GET` | `/api/{table}/capabilities` | Field access of the caller | `canView` | `200` | always |
| `POST` | `/api/{table}/query` | Run a `BeakQuerySpec` | `canView`, row scope, field read access | `200` page | always |
| `POST` | `/api/{table}/validate` | Check async rules without writing | Field write access, `canCreate` (no `recordId`) or `canUpdate` | `200` report | always |
| `POST` | `/api/{table}/aggregate` | One `count`, `sum` or `avg` | as `query` | `200` value | always |
| `POST` | `/api/{table}/summary` | Grouped `count` and `sum` measures | as `query` | `200` rows | always |
| `POST` | `/api/{table}/batch` | Fetch records by id | as `query` | `200` array | always |
| `POST` | `/api/{table}` | Create a record | `canCreate`, field write access, row scope of the new record | `201` record | always, closed for graph-only tables |
| `GET` | `/api/{table}/{id}` | Fetch one record | `canView`, row scope, field read access | `200` record | always |
| `PATCH` | `/api/{table}/{id}` | Update columns | `canUpdate`, field write access, row scope before and after | `200` record | closed for graph-only tables |
| `DELETE` | `/api/{table}/{id}` | Soft or hard delete | `canDelete`, row scope | `204` | closed for graph-only tables |
| `POST` | `/api/{table}/{id}/restore` | Clear the soft-delete marker | `canUpdate`, row scope | `200` record | closed for graph-only tables |
| `POST` | `/api/{table}/{id}/relations/{relationKey}/attach` | Link related ids | `canUpdate` on the owner, `canView` on the related table | `204` | closed for graph-only tables |
| `POST` | `/api/{table}/{id}/relations/{relationKey}/detach` | Unlink related ids | as `attach` | `204` | closed for graph-only tables |
| `POST` | `/api/{table}/export` | Stream matching rows as CSV | `canView`, row scope, field read access | `200` CSV | always |
| `POST` | `/api/{table}/{columnKey}/upload` | Store a file or image | Field write access, `canCreate` | `201` stored file | storage driver configured |
| `GET` | `/api/{table}/{columnKey}/upload?key={key}` | Resolve the URL of a stored key | `canView`, field read access, `BeakUploadReadPolicy`, row scope | `200` `{url}` | storage driver configured |
| `DELETE` | `/api/{table}/{columnKey}/upload` | Remove a stored key | Field write access, `canDeleteUpload` | `204` | storage driver configured |
| `POST` | `/api/auth/login` | Exchange credentials for a token | none | `200` session | `BeakAuthSessions` given |
| `POST` | `/api/auth/logout` | Revoke the presented token | none | `204` | `BeakAuthSessions` given |
| `GET` | `/api/auth/me` | The authenticated principal | none | `200` principal | `BeakAuthSessions` given |
| `GET` | `/healthz` | Liveness | none | `200` | always |
| `GET` | `/readyz` | Readiness | none | `200` or `503` | always |
| `GET` | `{publicBaseUrl path}/{key}` | Serve a locally stored file | none | `200` bytes | local-disk storage driver |

The route table itself is short. Everything under `/api/{table}` except `export` and the upload routes comes from one function:

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/beak_resource_router.dart:beakResourceRouter"
```

## Conventions

| Convention | Detail |
| --- | --- |
| Base path | `/api/{table}` for resources, `/api/commits`, `/api/auth`. The probes and the local file route sit outside `/api`. |
| Request bodies | JSON objects, UTF-8, at most 16 MiB (`beakMaxJsonBodyInBytes`). Invalid JSON, invalid UTF-8, or JSON that is not an object is a `422`; a longer body is a `413`. |
| Spec bodies | A `BeakQuerySpec` needs only `table`; missing keys take their defaults, so `{"table":"notes"}` is a valid query. Nested objects take their defaults too: a sort needs its `column`, a relation load its `relation`, a search its `term` and `columns`, and pagination can be empty. See [Queries](queries.md#required-keys). A spec that cannot be decoded is a `422 Malformed spec body: ...`. |
| Spec table | The `table` of a query, aggregate, summary or export body must equal the `{table}` of the path, or the request is a `422`. That includes a spec `table` that nobody registered (`Unknown table "ghosts".`). A path `{table}` nobody registered is a `404`. |
| Response bodies | JSON with `content-type: application/json; charset=utf-8`. Export answers CSV, the local file route answers the file's MIME type. |
| Ids in paths | The `{id}` segment is percent-decoded once (a key from an adopted database can hold a space or a slash, and the client encodes every segment), then coerced to the primary-key type. For an integer key a non-integer id is a `404`, and so is an id that is not valid percent-encoding. The `{saveId}` of a receipt lookup and the `{relationKey}` of attach and detach are decoded the same way. |
| Id lists | `batch`, `attach` and `detach` take at most 1000 ids per request, or a `422`. |
| Auth header | `Authorization: Bearer <token>`. No header means anonymous. When the server has an auth guard (any `BeakAuthSessions`, or an `authGuard`), a header that is not `Bearer`, or a token the store does not know, is a `401` on every route except the probes and `POST /api/auth/login`, which never ask the guard. Without a guard the header is ignored. |
| Request id | Every response carries `x-request-id`. An incoming value is reused when it is 1 to 128 letters, digits and `. _ : / -`, otherwise the server mints one. Error bodies repeat it as `requestId`. |
| CORS | `access-control-allow-origin` is `*` unless `corsOrigin` is set. `OPTIONS` answers `204`. Allowed request headers: `authorization`, `content-type`, `if-unmodified-since`, `x-request-id`. |
| Errors | One JSON envelope for every failure, see [The error envelope](#the-error-envelope). |

## Records and pages

A record is `{ "values": { ... }, "relations": { ... } }`. `values` maps a column key to a JSON primitive or list. A timestamp is tagged so decoding never mistakes it for a string. `relations` holds only the relations the query eager-loaded, each as a list of nested records. Beak never lazy-loads.

```json
{
  "values": {
    "id": "f7fd8ba6-6d50-4609-8903-5b2929c88736",
    "title": "Buy seed",
    "body": null,
    "pinned": true,
    "created_at": { "type": "dateTime", "value": "2026-09-29T10:16:57.440Z" },
    "updated_at": { "type": "dateTime", "value": "2026-09-29T10:16:57.440Z" }
  },
  "relations": {}
}
```

On writes the same value shapes are accepted: primitives, lists, `null` and the tagged timestamp. An object with any other shape is a `422 Malformed record body`. A belongs-to relation travels as its foreign-key column (`category_id`).

`POST .../query` answers a page:

```json
{ "items": [ { "values": { "...": "..." }, "relations": {} } ], "total": 1, "page": 1, "perPage": 25 }
```

`total` counts all pages, `page` is 1-based, `perPage` defaults to `25`. The server serves at most 200 rows per page (`BeakPagination.maxPerPage`): a request for more is answered with 200 and the envelope's `perPage` says so, while `total` still counts every row. Page through the rest.

## Graph commits

`POST /api/commits` saves a whole graph (an order with its items and a new customer, say) in one transaction and returns a receipt. Every form save, table delete, import row and bulk edit in the panel goes through it. The mechanics are in [Graph commits](../architecture/graph-commits.md); this section is the wire contract.

```dart title="packages/beak_backend/lib/src/endpoints/commit_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/commit_router.dart:registerBeakCommitRoutes"
```

The routes exist for every data source. Over a `WormDataSource` the `_beak_commit_receipts` table must exist (`BeakCommitReceiptsMigration` is in every generated `migrations:` list). Over any other source the save is `staged`: the same authorization, the writes one by one through the source's CRUD calls with no rollback, and receipts kept in memory (see [Graph commits](../architecture/graph-commits.md)).

### Request

A `BeakSavePlan`, built with the typed `BeakSaveOperation` constructors and serialized by `BeakClient.commit`. A hand-written plan for one create:

```bash
curl -s -X POST localhost:8080/api/commits -H 'content-type: application/json' -d '{
  "saveId": "s1",
  "root": { "table": "notes", "draftId": "n" },
  "operations": [{
    "id": "n", "kind": "create",
    "target": { "table": "notes", "draftId": "n" },
    "values": { "values": { "title": "From a plan", "pinned": false }, "relations": {} },
    "references": {}, "dependsOn": []
  }]
}'
```

| Plan key | Type | Meaning |
| --- | --- | --- |
| `saveId` | `String`, 1 to 200 characters | Idempotency key, scoped to the calling principal |
| `root` | `{table, id}` or `{table, draftId}` | The record the form edits |
| `operations` | list, at most 1000 | The writes |
| `action` | `String?` | A `BeakModelAction` name to run on the root in the same transaction |
| `arguments` | record | Inputs of that action |

| Operation key | Meaning |
| --- | --- |
| `id` | Unique within the plan |
| `kind` | `create`, `update`, `delete`, `attach`, `detach` |
| `target` | `{table, id}` for an existing record, `{table, draftId}` for one the plan creates |
| `values` | The record shape of the columns to write |
| `references` | Column key to record reference, resolved to the referenced record's id |
| `dependsOn` | Operation ids that must run first |
| `owner`, `relationKey`, `related` | Ownership and link endpoints |
| `expectedUpdatedAt` | ISO-8601 UTC version the editor loaded, for `update` and `delete` |

### Response

`200` whenever the plan was understood and its `saveId` was not reused with another plan. The HTTP status describes the request, not the save.

```json
{
  "saveId": "s1",
  "mode": "atomic",
  "outcomes": [
    {
      "id": "n",
      "status": "applied",
      "draftId": "n",
      "resolvedId": "3bd3e500-291f-49b2-a3a0-f79597d9b92c",
      "table": "notes",
      "record": { "values": { "id": "3bd3e500-291f-49b2-a3a0-f79597d9b92c", "title": "From a plan", "...": "..." }, "relations": {} }
    }
  ],
  "rootOperationId": "n"
}
```

A save that failed validation is still a `200`. Nothing was written, and every operation says so:

```json
{
  "saveId": "s2",
  "mode": "atomic",
  "outcomes": [
    {
      "id": "n",
      "status": "unapplied",
      "error": { "code": "validation", "message": "Validation failed for \"notes\".", "fieldErrors": { "title": ["This field is required."] } },
      "reason": "rejected"
    }
  ],
  "rootOperationId": "n"
}
```

A denied write reports the same way. An anonymous delete against a policy that requires a signed-in principal:

```json
{
  "saveId": "a2",
  "mode": "atomic",
  "outcomes": [
    {
      "id": "d",
      "status": "unapplied",
      "error": { "code": "authentication", "message": "Authentication is required.", "fieldErrors": {} },
      "reason": "rejected"
    }
  ]
}
```

Read `complete` (all operations `applied`), `mode` (`atomic` or `staged`) and each `status` before reporting success. The types, `reason` values and the `unknown` status are in [Exceptions](exceptions.md#failures-inside-a-receipt).

### Replay and recovery

The receipt key is the hash of the principal id and the `saveId`, so two users can both send `save-1`.

| Situation | Answer |
| --- | --- |
| Same `saveId`, same plan, receipt exists | `200` with the stored receipt, no write, no hook runs |
| Same `saveId`, different plan | `409 conflict`, `Save identity was reused with different content.` |
| Another principal, same `saveId` | A separate save |
| Plan body not decodable | `422 validation`, `Malformed spec body: ...` |
| Plan decodes but is invalid (unknown field, unregistered table, duplicate operation id, cycle) | `422 validation`, for example `Invalid save plan: Unknown field "nope".` |
| Token invalid or expired | `401` from the auth guard, before the plan is read. A denied operation is inside the receipt instead. |

`GET /api/commits/{saveId}` reads the stored receipt and repeats nothing. It answers `404 No receipt for save "..."` for an id the principal never used. It needs `canView` on every table in the plan, checks that applied records are still inside the caller's row scope, and redacts fields the caller may not read. A rejected atomic save is final for its `saveId`; a script that retries must mint a new one. Receipts are never deleted.

### Closed direct routes

Writing around a graph rule with `PATCH` would defeat it, so `beakApiRouter` answers the direct write routes of some tables with a `422`. The `graphOnly:` list of `BeakServerDefaults.build` names them; the router adds any table with non-empty `behavior`, any owned child of a model with `editableWhen`, and any table that validation rules or behavior load relations from.

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/beak_resource_router.dart:graphOnlyGuards"
```

```bash
curl -s -X PATCH localhost:8080/api/notes/abc -H 'content-type: application/json' -d '{"title":"x"}'
```

```json
{ "code": "validation", "message": "This resource must be saved through a graph commit.", "requestId": "a67e71ae93c9b967" }
```

The closed routes are create, update, delete, restore, attach and detach. Reads, `validate`, `capabilities`, `export` and the upload routes stay open. `graphOnly` needs no `preparePlan`: without one, the direct routes are closed and the commit route saves the table under the usual authorization and validation.

## Capabilities and validation

`GET /api/{table}/capabilities` answers which fields the caller may read and write, which named model actions it may run, and whether it may create and delete records. The panel uses it to hide inputs and buttons. It is presentation metadata: the server authorizes every request again.

```bash
curl -s "localhost:8080/api/notes/capabilities?id=f7fd8ba6-6d50-4609-8903-5b2929c88736"
```

```json
{
  "readableFields": ["id", "title", "body", "pinned", "created_at", "updated_at"],
  "writableFields": ["id", "title", "body", "pinned", "created_at", "updated_at"],
  "executableActions": [],
  "canCreate": true,
  "canDelete": false
}
```

A `null` list means "all". An empty list means "none". `canCreate` and `canDelete` are booleans from the same policy that gates `POST` and `DELETE`; a server that predates them sends neither, which a client reads as allowed. The optional `id` selects an existing record and must be inside the caller's row scope, otherwise `404`. Without an `id`, `canDelete` is the policy's answer for a record that has no id yet: exact for role rules such as `BeakPolicies`, and a lower bound for a policy that decides per record, so ask with the `id` for those.

`POST /api/{table}/validate` runs the asynchronous rules (uniqueness, relationship eligibility) on a candidate without writing. The body is a `BeakValidationRequest`:

```bash
curl -s -X POST localhost:8080/api/notes/validate -H 'content-type: application/json' \
  -d '{"table":"notes","record":{"values":{"title":"x","pinned":false},"relations":{}}}'
```

```json
{ "fieldErrors": {} }
```

| Body key | Meaning |
| --- | --- |
| `table` | Must equal the path table, else `422 Validation targets the wrong resource.` |
| `record` | A record: `{values, relations}` |
| `recordId` | Present for an edit (the record is excluded from uniqueness checks), absent for a create |

A `200` with a non-empty `fieldErrors` means the candidate failed. Synchronous rules and whole-graph invariants still run on save, and the check reserves nothing.

## Query, aggregate, summary, batch

All four take the table's read gate. The specs are documented in [Queries](queries.md).

| Route | Body | Response |
| --- | --- | --- |
| `POST .../query` | `BeakQuerySpec` | Page envelope, see above |
| `POST .../aggregate` | `BeakAggregateSpec` (`table`, `function`: `count`, `sum` or `avg`, `column`) | `{ "value": 1 }` |
| `POST .../summary` | `BeakSummarySpec` (`table`, `groupBy`, `measures`, `limit`, ...) | `{ "rows": [{ "group": true, "values": { "notes": 1 } }], "truncated": false }` |
| `POST .../batch` | `{ "ids": [...] }` with integers or strings | Array of records; ids that match no visible record are absent |

```bash
curl -s -X POST localhost:8080/api/notes/summary -H 'content-type: application/json' \
  -d '{"table":"notes","groupBy":"pinned","measures":[{"key":"notes","column":null}],"filter":null,"search":null,"limit":100,"withTrashed":false}'
```

```json
{ "rows": [{ "group": true, "values": { "notes": 1 } }], "truncated": false }
```

A row scope is folded into the spec's filter before the data source runs it, so `total`, `aggregate` and `summary` never count rows the caller cannot see. `summary` needs a data source that implements `BeakSummaryDataSource`, otherwise `500 This data source does not support summaries.`

## Single-record routes

These are the routes a script uses. They are closed (`422`) for graph-only tables.

### Create

`POST /api/{table}` takes a flat `{ "column": value }` body, not the record envelope.

```bash
curl -s -X POST localhost:8080/api/notes -H 'content-type: application/json' -d '{"title":"Buy seed","pinned":true}'
```

The answer is `201` with the created record. Rule failures are a `422` with every field listed:

```json
{
  "code": "validation",
  "message": "Validation failed for \"notes\".",
  "fieldErrors": { "title": ["This field is required."], "pinned": ["This field is required."] },
  "requestId": "1c63e624ca6a571a"
}
```

A belongs-to foreign key in the body must point at a related record the caller may view, otherwise the request is refused.

### Fetch one

`GET /api/{table}/{id}` answers `200` with the record, or `404 No record of "notes" with id "zzz".` A row outside the row scope is a `404` as well.

### Update

`PATCH /api/{table}/{id}` takes a flat body of the columns to change; omitted columns keep their value. The answer is `200` with the updated record.

`If-Unmodified-Since` makes the write conditional. The value is the `updated_at` the caller read, as an ISO-8601 timestamp. If the stored `updated_at` differs, the answer is `409`; a value that does not parse is a `422`. Without the header the update is unconditional (last write wins).

```bash
curl -s -X PATCH localhost:8080/api/notes/f7fd8ba6-6d50-4609-8903-5b2929c88736 \
  -H 'content-type: application/json' -H 'if-unmodified-since: 2020-01-01T00:00:00Z' -d '{"title":"x"}'
```

```json
{
  "code": "conflict",
  "message": "Record \"f7fd8ba6-6d50-4609-8903-5b2929c88736\" of \"notes\" changed since it was read (expected 2020-01-01 00:00:00.000Z, found 2026-09-29 10:17:04.736Z).",
  "requestId": "842733c76fe38783"
}
```

The model needs a `BeakDateTimeColumn` keyed `updated_at` (`@Resource(timestamps: true)`), otherwise the conditional update is a `422`. Timestamps are compared at millisecond precision.

The server applies the edits, deletes and restores of one record one at a time, so two requests that carry the same `If-Unmodified-Since` cannot both win: the second one reads the new `updated_at` and answers `409`. That order is kept inside one server process. With several instances behind a balancer, the version check that holds is a graph commit's `expectedUpdatedAt`, which is one SQL statement.

### Delete and restore

`DELETE /api/{table}/{id}` answers `204`. On a model with `@Resource(softDeletes: true)` it sets `deleted_at`; `?force=true` deletes the row for real (and may target an already soft-deleted row). A missing row is a `404`.

`POST /api/{table}/{id}/restore` clears `deleted_at` and answers `200` with the record. It needs `canUpdate`, not `canDelete`. Find deleted rows first with a query that sets `"withTrashed": true`. On a model without soft deletes it is a `422`.

### Attach and detach

`POST /api/{table}/{id}/relations/{relationKey}/attach` (and `detach`) takes `{ "ids": [...] }` and answers `204`. It works on to-many relations only (belongs-to-many and has-many); anything else is a `422`, an unknown relation key a `404`. The caller needs write access to the relation field, `canUpdate` on the owner, `canView` on the related table, and `canUpdate` on each related record for has-many. The whole selection is checked before any link is written.

## Export

`POST /api/{table}/export` streams the rows a `BeakQuerySpec` matches as a CSV attachment named `{table}.csv`. It applies the same row scope, field access and password redaction as `query`.

```bash
curl -s -X POST localhost:8080/api/notes/export -H 'content-type: application/json' -d '{"table":"notes"}'
```

```text
Title,Pinned,Updated
Buy seed v2,true,2026-09-29T10:17:04.736Z
```

The body is a query spec plus optional keys:

| Key | Type | Meaning |
| --- | --- | --- |
| `columns` | `List<String>` | Column keys in output order. Non-empty, unique, known. Default: the model's table-context columns. Columns the caller may not read are dropped. |
| `formatting` | `BeakFormatPolicy` JSON | Locale, currency and date patterns for display values. Default: none. |
| `formats` | `{ "<key>": { "format", "minorUnits", "scale" } }` | Per-column display override. `scale` is 0 to 12. Keys must be among the selected columns. |
| `raw` | `bool` | Physical storage values, no display formatting. Cannot be combined with `formatting` or `formats`. Default `false`. |

The first page is queried before the response starts, so validation errors arrive as normal error envelopes. A failure on a later page truncates the stream, because the status line is already sent. See [Search and export](../backend/search-and-export.md).

## Uploads

The routes are mounted when the server has a storage driver. `beak create` projects default to local disk under `storage/uploads`; `BEAK_STORAGE_DRIVER=none` turns the routes off. The `{columnKey}` must name a file or image column; an unknown key is a `404`, another column type a `422`.

```dart title="packages/beak_backend/lib/src/uploads/upload_router.dart"
--8<-- "packages/beak_backend/lib/src/uploads/upload_router.dart:registerUploadRoutes"
```

### Store

`POST /api/{table}/{columnKey}/upload` takes `multipart/form-data` with the file in a part named `file`. The read is bounded by the column's `maxSizeInBytes` while streaming, or by 100 MiB when the column sets none. The stored key is minted by the server; only a short plain extension (letters and digits) of the client filename is kept. Image columns are decoded, checked against `allowedTypes`, dimensions and aspect ratio, and run through their transforms.

```bash
curl -s -X POST localhost:8080/api/product_images/image/upload -F "file=@pic.png;type=image/png"
```

```json
{
  "key": "product-images/62d9064d-227c-4889-9bdc-d9aa35317c67.png",
  "url": "http://127.0.0.1:8080/uploads/product-images/62d9064d-227c-4889-9bdc-d9aa35317c67.png",
  "sizeInBytes": 156,
  "mimeType": "image/png",
  "widthInPixels": 64,
  "heightInPixels": 64,
  "variants": {
    "thumbnail": {
      "key": "product-images/62d9064d-227c-4889-9bdc-d9aa35317c67_thumbnail.png",
      "url": "http://127.0.0.1:8080/uploads/product-images/62d9064d-227c-4889-9bdc-d9aa35317c67_thumbnail.png",
      "widthInPixels": 480,
      "heightInPixels": 480
    }
  }
}
```

The answer is `201`. Store the `key` (and the variant keys) in the record's column. The `url` is the driver's URL for the key at upload time.

| Failure | Answer |
| --- | --- |
| Body is not multipart, or has no `file` part | `422` |
| File larger than `maxSizeInBytes` | `422`, `fieldErrors: { "size": ["The file exceeds the limit of N bytes."] }` |
| Wrong type, dimensions or aspect ratio | `422` |
| Bytes that are not a supported raster image, for an image column | `422 The uploaded file is not a supported raster image (PNG, JPEG, WebP or GIF).` |
| Driver failure | `500 storage` |

### Resolve

`GET /api/{table}/{columnKey}/upload?key={key}` answers `{ "url": "..." }` for an existing key that starts with the column's `storagePath`. A key outside that path is a `422`, a key with no stored file a `404`, and a missing `key` a `422`. When the table has a row scope, the key must be referenced by a record the caller can see in that column; unreferenced and hidden keys both answer `404`.

The URL comes from `storage.url(key, expiresIn: signedUrlLifetime)`. A driver that signs (S3) answers with a presigned link that expires after `signedUrlLifetime` (one hour unless `defaults.build(signedUrlLifetime:)` says otherwise), unless `BEAK_S3_PUBLIC_BASE_URL` is set, in which case the public address is answered. A local-disk, memory or FTP URL is the same public address every time.

### Remove

`DELETE /api/{table}/{columnKey}/upload` takes `{ "key": "..." }`, checks `canDeleteUpload` for that exact key and answers `204`. A key with no stored file is a `404`. `BeakClient.discardUpload` calls it once per rendition and treats a `404` as already gone.

### Local files

With the local-disk driver, `GET {publicBaseUrl path}/{key}` (default `/uploads/{key}`) serves the stored file with its MIME type and `content-length`, plus `x-content-type-options: nosniff` and a sandboxing `content-security-policy` (HTML, SVG and XML also get `content-disposition: attachment`). It is read-only, has no auth, and answers `404` for a missing file or a key that climbs out of the root, by `..` or by a symbolic link. Set `BEAK_LOCAL_PUBLIC_BASE_URL` to a CDN and the route is no longer used.

## Auth routes

Mounted under `/api/auth` when the server is built with `BeakAuthSessions`. They ignore policies.

```dart title="packages/beak_backend/lib/src/auth/auth_router.dart"
--8<-- "packages/beak_backend/lib/src/auth/auth_router.dart:beakAuthRouter"
```

| Route | Body | Answer |
| --- | --- | --- |
| `POST /api/auth/login` | `{ "username": "...", "password": "..." }` | `200` `{ "token": "<64 hex characters>", "principal": { "id": "admin", "roles": ["admin"] } }` |
| `POST /api/auth/logout` | none; `Authorization: Bearer <token>` | `204` |
| `GET /api/auth/me` | none; `Authorization: Bearer <token>` | `200` `{ "id": "admin", "roles": ["admin"] }` |

Wrong credentials are `401 Invalid username or password.`; a missing string in the body is a `422`. Logout without a `Bearer` header is `401`, and so is logging out with a token that is already revoked. `me` without a session is `401 Sign in to continue.`

Passwords are compared as an HMAC-SHA256 hash under the server's secret (`hashBeakPassword`). Tokens are opaque and live in a `TokenSessionStore`; the default `InMemoryTokenSessionStore` keeps them in process memory for 12 hours and loses them on restart. A guard resolves the principal on every request. With no `Authorization` header the request is anonymous, and the policy decides.

## Health probes

Two probes for container platforms, mounted before the API.

```dart title="packages/beak_backend/lib/src/endpoints/health_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/health_router.dart:beakHealthRouter"
```

| Probe | Answer |
| --- | --- |
| `GET /healthz` | `200` `{"status":"ok"}` while the process serves. Never touches the database. |
| `GET /readyz` | `200` `{"status":"ok"}` when the data source answers a count on the first registered model. `200` with `"detail":"no models registered"` for an empty registry. `503` `{"status":"unavailable","detail":"the data source did not answer"}` otherwise. |

The `503` body names no cause, because the probe is unauthenticated. The failure goes to `onUnexpectedError`. Neither probe needs a token. On a server with an auth guard, a probe that sends an invalid `Authorization` header is still a `401`, because authentication wraps the whole router; a platform probe sends none.

## The error envelope

Every failure is one JSON object. `beakErrorMappingMiddleware` maps the sealed `BeakException` family to a status and anything untyped to a fixed `500`.

```json
{ "code": "not_found", "message": "No record of \"notes\" with id \"zzz\".", "requestId": "037380970a4a77a6" }
```

| `code` | Status | Meaning on this API |
| --- | --- | --- |
| `validation` | `422` | Bad JSON, bad spec (including an unknown table, field or relationship, or an operand that does not fit its operator), failed rule, read-only field, graph-only route, upload rule. Carries `fieldErrors` when the failure is per field. |
| `not_found` | `404` | Unknown route, record (or one outside the row scope), relation, upload key or receipt |
| `authentication` | `401` | No valid session, wrong login, or a policy that denied an anonymous request |
| `authorization` | `403` | A policy denied a signed-in principal |
| `conflict` | `409` | Stale `If-Unmodified-Since`, reused `saveId` with another plan, duplicate unique value |
| `configuration` | `500` | Beak is wired wrong: a model relates to a table nobody registered, an environment value is malformed |
| `storage` | `500` | A storage driver failed |
| `internal` | `500` | Anything untyped. The body is always `Internal server error.` |
| `payload_too_large` | `413` | A body larger than the host accepts. Beak itself does not send it; a proxy or the Serverpod tunnel does. |
| `transport` | `502` | A fault outside Beak's API (a tunnel's own error). Beak itself does not send it. |

[Exceptions](exceptions.md) lists what raises each code and how `BeakClient` turns a body back into a type.

## Rules and limits

- `BeakPolicies` denies whatever it does not list. The default `BeakAllowAllPolicy` allows every route above to every caller, which suits tests and first runs only.
- Row scoping is enforced in the service layer for query, aggregate, summary, batch, get, update, delete, restore, attach, detach, export, uploads and graph commits. An excluded row reports as `404`, never `403`.
- The graph-commit routes exist for every data source, but only a `WormDataSource` on a transactional adapter saves atomically. Any other source saves `staged`, with in-memory receipts.
- A commit plan that decodes but is invalid (unknown field, unregistered table, cycle) answers `422 validation`.
- A page size above 200 is served as 200. A page whose offset would pass 2^53 - 1 rows is a `422`.
- `%`, `_` and `\` in `contains`, `startsWith`, `endsWith` and search terms match themselves. In a `like` or `ilike` operand, which is a pattern, `%` and `_` are wildcards and a backslash escapes the next character: `50\%` matches the text `50%`.
- Timestamps in a spec travel as UTC instants, `2026-06-01T12:30:45.123Z`, whatever zone the client built them in.
- A dotted sort key such as `category.name`, and an aggregate or summary column reached through a relationship, is a `422`. Sort by a column of the queried table.
- `If-Unmodified-Since` guards `PATCH` only. Graph commits carry their own `expectedUpdatedAt`.
- Behind the Serverpod admin app the `/api` routes run through a tunnel with the same paths and bodies. `/api/auth/**`, the probes and the file route are not forwarded, see [Serverpod](../serverpod/index.md).

## Source

- `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart` mounts everything (`beakApiRouter`, `beakResourceRouter`).
- `packages/beak_backend/lib/src/endpoints/crud_handlers.dart` holds the resource handlers.
- `packages/beak_backend/lib/src/endpoints/commit_router.dart` and `packages/beak_backend/lib/src/service/beak_graph_commit_service.dart` implement the commit routes.
- `packages/beak_backend/lib/src/endpoints/health_router.dart` and `packages/beak_backend/lib/src/endpoints/local_uploads_router.dart` hold the probes and the local file route.
- `packages/beak_backend/lib/src/export/export_router.dart` and `packages/beak_backend/lib/src/uploads/upload_handler.dart` hold the export and upload handlers.
- `packages/beak_backend/lib/src/auth/auth_router.dart` holds login, logout and `me`.
- `packages/beak_backend/lib/src/server/middleware` holds the request-log, CORS, JSON, error-mapping and auth middleware.
- `packages/beak_core/lib/src/client/beak_client.dart` is the typed client for every route.
- `packages/beak_core/lib/src/data/beak_commit.dart` defines the plan and receipt types.

## Continue reading

- [Exceptions](exceptions.md) lists what raises each error code and how the client rebuilds it.
- [Queries](queries.md) documents the spec bodies `query`, `aggregate`, `summary` and `export` accept.
- [Graph commits](../architecture/graph-commits.md) explains the transaction, receipts and the hooks behind `/api/commits`.
- [Auth and policies](../backend/auth-and-policies.md) shows how to write the policies these routes call.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) covers the drivers behind the upload routes.
- [Configuration and environment](configuration.md) lists the variables that stand this server up.
