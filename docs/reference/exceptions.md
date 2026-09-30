---
title: Exceptions
description: The sealed BeakException family, the code and HTTP status each variant carries, what throws it, and how the client, receipts and the panel decode it.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Exceptions

Beak raises one sealed family of failures, `BeakException`. Each variant has a stable `code` that travels in the JSON error body, an HTTP status the backend maps it to, and a place where it is rebuilt on the client. This page lists all of it, plus the receipt types that carry a failure inside a `200`.

## Import

```dart
import 'package:beak/beak.dart';
```

The family lives in `beak_core`, so server code, panel code and tests share the same types. The status mapping lives in `beak_backend` (`package:beak/server.dart`); `beakRun` lives in `beak_frontend` (`package:beak/panel.dart`).

## Summary

| Exception | `code` | HTTP status | Typical cause | Extra members |
| --- | --- | --- | --- | --- |
| `BeakValidationException` | `validation` | 422 | A rule failed, a body or spec is malformed, a read-only field was written, a graph-only route was called | `fieldErrors` |
| `BeakNotFoundException` | `not_found` | 404 | Unknown record (or one outside the row scope), route, relationship, upload key or receipt | none |
| `BeakAuthenticationException` | `authentication` | 401 | No valid identity: wrong login, unknown or expired token, or a policy that denied an anonymous request | none |
| `BeakAuthorizationException` | `authorization` | 403 | A policy, field policy or row scope denied a signed-in principal | none |
| `BeakConflictException` | `conflict` | 409 | Duplicate unique value, stale version, reused `saveId` or effect identity | none |
| `BeakConfigurationException` | `configuration` | 500 | Beak is wired wrong: unregistered model, invalid environment value, unsupported data source | none |
| `BeakStorageException` | `storage` | 500 | A storage driver failed, or a storage key is invalid | none |
| `BeakInternalException` | `internal` | 500 | The server failed unexpectedly; also what the client reports for a 5xx it cannot type | none |
| `BeakPayloadTooLargeException` | `payload_too_large` | 413 | A JSON body is over 16 MiB, or a request body is larger than the proxy or tunnel accepts | none |
| `BeakTransportException` | `transport` | 502 | A response never reached Beak's error format and no other type fits | none |
| `BeakRecordShapeException` | `configuration` | 500 | `require` on a column or typed field found no readable value | `columnKey`, `expectedType` |
| any other `Object` thrown on the server | `internal` | 500 | A bug or an infrastructure failure | none (the body is fixed) |

`BeakRecordShapeException` extends `BeakConfigurationException`, so it maps to the same status and code. The sealed switch in the middleware covers ten direct variants; `BeakRecordShapeException` rides along with its parent. The server answers an untyped failure with the fixed `internal` body. `BeakInternalException` is the type a client rebuilds from that body, and what server code throws when it wants a 500 with a message of its own. `BeakTransportException` is a client-side type: the server never sends `transport`, but the Serverpod tunnel does.

## The base type

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
--8<-- "packages/beak_core/lib/src/common/beak_exception.dart:BeakException"
```

| Member | Type | Meaning |
| --- | --- | --- |
| `code` | `String` | Stable machine-readable category. The only field a client should switch on. |
| `message` | `String` | Text for a person. Not stable, do not parse it. |
| `toString()` | `String` | `<runtimeType>(<code>): <message>` |

Because the class is `sealed`, a `switch` over a `BeakException` is checked for completeness. Adding a variant breaks every mapper that does not handle it.

## The variants

`BeakValidationException` is the only variant with a payload.

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
--8<-- "packages/beak_core/lib/src/common/beak_exception.dart:BeakValidationException"
```

`fieldErrors` maps a column key (or a relationship key) to every message for that field. The server collects all rule failures before it throws, so a form can mark every input at once.

The other nine take a message and set their `code`:

```dart title="packages/beak_core/lib/src/common/beak_exception.dart"
--8<-- "packages/beak_core/lib/src/common/beak_exception.dart:BeakOtherExceptions"
```

`BeakRecordShapeException` is the one subclass:

| Member | Type | Meaning |
| --- | --- | --- |
| `BeakRecordShapeException({required columnKey, required expectedType})` | constructor | Builds the message from both values |
| `columnKey` | `String` | The column whose value could not be read |
| `expectedType` | `Type` | The Dart type the column reads its values as |

`BeakTypedColumn.require` and `BeakScalarField.require` throw it when the record has no readable value for the column (absent, `null`, or the wrong shape). Their counterpart `readFrom` returns `null` instead.

## What throws each variant

Messages below were captured from a running quickstart server unless marked "source". The exact text is not part of the contract, the `code` is.

### validation (422)

| Cause | Message or field error |
| --- | --- |
| A column rule failed on create or update | `Validation failed for "notes".` with `fieldErrors: {"title": ["This field is required."]}` |
| Body is not UTF-8 or JSON, or not a JSON object | `Request body must be a JSON object, got [1].` |
| A query, aggregate, summary, commit or validation body cannot be decoded | `Malformed spec body: BeakSavePlan JSON is missing the "root" key.` |
| A spec names another table than the path | `Query spec targets "x" but this endpoint serves "notes".` (source) |
| A direct write to a graph-only table | `This resource must be saved through a graph commit.` |
| A read-only field was sent | `Read-only fields cannot be written.` with `fieldErrors: {"<key>": ["This field is read-only."]}` (source) |
| `restore` on a model without soft deletes | `Model "notes" does not soft-delete, so there is nothing to restore.` |
| `If-Unmodified-Since` is not ISO-8601 | `"if-unmodified-since" must be an ISO-8601 timestamp, got "yesterday".` |
| Upload is not multipart, has no `file` part, exceeds the size limit, or breaks a type rule | `Upload requests must be multipart/form-data with a "file" field.`, `The multipart body has no "file" field.`, `fieldErrors: {"size": [...]}` |
| An upload key does not start with the column's storage path | `Key "other/x.png" does not belong to column "image" (expected the "product-images/" prefix).` |
| `batch`, `attach` or `detach` got bad ids | `Ids must be integers or strings, got 1.5.` |
| Login body lacks a string | `Request body must carry a "password" string, got null.` |
| A query names an unknown table, field or relationship | `Unknown table "ghosts".`, `Unknown field "nope" on "notes".`, `Unknown relationship "title".` |
| A sort, aggregate column, summary group or summary measure reaches through a relationship | `Sort key "category.name" must be a column of "products" itself, not a field reached through a relationship.` |
| An aggregate sums or averages a column that is not numeric | `Aggregate column "title" must be numeric.` |
| A filter operand does not fit its operator or its column | `Operator "contains" on "title" needs a string operand, got 5.`, `Operator "between" on "rating" needs exactly two bounds, ...`, `Operator "gt" on "rating" needs an integer operand, got "abc".`, `Operator "eq" on "title" needs a single value, got a list.`, `Operator "contains" on "rating" only applies to text fields.` |
| The database refuses a value in a filter (an integer outside an `integer` column) | `A value in the request does not fit the field it is compared with.` |
| A write breaks a foreign key, a CHECK or NOT NULL rule, or a column's size or range | `A record this one refers to does not exist.`, `A value is missing or not allowed.`, `A value is too long or out of range for its column.` (with a field error when the driver names the column) |
| A search names a column or relationship that does not exist, or one that cannot be searched | `Model "notes" has no column "bogus".`, `Password column "secret" cannot be searched.` |
| A relationship filter reaches more than 16 levels | `Relationship filter exceeds 16 levels.` |
| A page whose offset no database can address | `Page 9007199254740992 is out of range for 200 records per page.` |
| A plan names an `action` and the data source is not transactional | `This data source cannot run a named action: actions need a transactional data source.` |

### not_found (404)

| Cause | Message |
| --- | --- |
| Unknown or out-of-scope record | `No record of "notes" with id "zzz".` |
| No route matches | `No handler for GET /api/nope.` |
| Unknown relationship key on attach or detach | `Unknown relationship "nope".` |
| Unknown upload column | `Model "notes" has no column "nope".` |
| Upload key with no stored file | `No stored file "product-images/none.png".` |
| `GET /api/commits/{saveId}` for an id the principal never used | `No receipt for save "nope".` |
| A local-disk file route with no file, or a key that climbs out of the root | `No stored file at "none.txt".` |

An integer primary key with a non-integer path id is a 404, never a crash. A row that a row policy excludes reports as missing too, because "forbidden" would tell the caller the row exists.

### authentication (401)

| Cause | Message |
| --- | --- |
| Wrong username or password | `Invalid username or password.` |
| Token unknown, revoked or expired | `The session token is invalid or expired.` |
| `Authorization` header is not `Bearer <token>` | `The authorization header must carry a Bearer token.` |
| `GET /api/auth/me` without a session | `Sign in to continue.` |
| `POST /api/auth/logout` without a header | `A Bearer token is required to log out.` |
| A policy denied `null` principal | `Sign in to update "notes".` (the action varies) |
| A graph operation was denied to `null` | `Authentication is required.` (inside a receipt) |

### authorization (403)

| Cause | Message |
| --- | --- |
| A policy denied a signed-in principal | `Principal "admin" is not allowed to update "notes".` (source, the action varies) |
| A graph operation was denied | `This operation is not permitted.` (inside a receipt) |
| A create or an update would leave the record outside the row scope | `The record would be outside your permitted scope of "notes".` (source) |
| A field policy denied a field | `Principal "x" is not allowed to write field "y" of "notes".` (source) |

`enforcePolicyDecision` picks between the two: a denied `null` principal raises `BeakAuthenticationException`, a denied principal raises `BeakAuthorizationException`.

### conflict (409)

| Cause | Message |
| --- | --- |
| A unique constraint fired on insert or update | `A value that must be unique is already in use.` |
| A row other records still reference is force-deleted | `This "notes" record is still referenced by other records.` |
| `If-Unmodified-Since` is older than the stored `updated_at` | `Record "<id>" of "notes" changed since it was read (expected <a>, found <b>).` |
| `expectedUpdatedAt` in a graph operation is stale | `The record changed since it was loaded.` (inside a receipt) |
| A `saveId` was reused with a different plan | `Save identity was reused with different content.` |
| An outbox effect identity was reused with different content | `Effect identity was reused with different content.` (source) |
| The Serverpod auth adapter rate-limited a sign-in | `Too many sign-in attempts.` (source) |

### configuration (500)

| Cause | Message |
| --- | --- |
| A model's relationship points at a table nobody registered | `No model registered for table "ghosts".` |
| `DATABASE_URL`, `PORT` or `HOST` is malformed | `PORT must be an integer between 1 and 65535, got "x".` (source) |
| A preparer, finalizer or model behavior meets a non-transactional data source | `Graph preparation requires a transactional data source.` (source) |
| The data source cannot summarize | `This data source does not support summaries.` (source) |
| A storage driver is selected but not registered | `No storage driver is registered for "s3". Registered drivers: memory, local.` (source, raised at boot) |

### storage (500)

The messages below are what the exception carries. Over HTTP every one of them becomes `File storage failed.`, and the original goes to `onUnexpectedError`.

| Cause | Message |
| --- | --- |
| A driver has no file under a key | `No file is stored under "key".` |
| A key is empty, absolute, uses backslashes or has a `.` or `..` segment | `Storage key "x" must be relative, not absolute.` (source) |
| S3 or FTP failed | `S3 <operation> failed for "<key>": <driver error>` |

The S3 driver appends the driver's own error text to the message. The middleware does not send it: the caller gets `{"code":"storage","message":"File storage failed."}`. Code that calls a driver directly sees the full text.

### internal (500), payload_too_large (413) and transport (502)

| Cause | Type and message |
| --- | --- |
| Any exception that is not a `BeakException` reaches the middleware | `internal`, always `Internal server error.` |
| Server code throws `BeakInternalException` | `internal`, the message it carries |
| The client reads a `5xx` with no Beak error code (a proxy's error page, an empty body) | `BeakInternalException`, message `HTTP 502.` |
| The client reads a `413`, or the tunnel reports one (Serverpod's `maxRequestSize`) | `BeakPayloadTooLargeException` |
| The client reads a status Beak does not use (a `400` or `3xx` with no Beak code), or the tunnel reports a fault it cannot name | `BeakTransportException` |

## How an exception becomes a response

`beakErrorMappingMiddleware` is the only catch boundary of the HTTP layer. It sits inside the request-log, CORS and JSON middleware and outside authentication, so a `BeakAuthenticationException` thrown by the guard is mapped like any other.

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
--8<-- "packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart:beakErrorMappingMiddleware"
```

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
--8<-- "packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart:exceptionStatus"
```

The body is JSON with `content-type: application/json; charset=utf-8`.

| Key | Present | Meaning |
| --- | --- | --- |
| `code` | always | The variant's `code`, or `internal` |
| `message` | always | The exception's message, or `Internal server error.` |
| `fieldErrors` | only for `BeakValidationException` with at least one entry | `{ "<key>": ["<message>", ...] }` |
| `requestId` | when the request-log middleware is installed (it is, in `BeakServer`) | The incoming `x-request-id` when it is a plain token (at most 128 letters, digits and `. _ : / -`), or one minted per request. The same value is echoed as the `x-request-id` response header. |

Real bodies:

```json
{
  "code": "validation",
  "message": "Validation failed for \"notes\".",
  "fieldErrors": { "title": ["This field is required."], "pinned": ["This field is required."] },
  "requestId": "1c63e624ca6a571a"
}
```

```json
{ "code": "internal", "message": "Internal server error.", "requestId": "1103bf8bc84f1c1d" }
```

An error that is not a `BeakException` is passed to `onUnexpectedError` (default: stderr) and answered with the fixed `internal` body. Driver messages, host names and stack traces stay on the server. The per-route status codes are in the [REST API](rest-api.md).

## What the client rebuilds

`BeakClient` decodes every non-2xx response by `code`. When the body has no code, or one this client does not know, the HTTP status decides. It is the transport under `HttpBeakDataSource`, so panel code sees the same types.

```dart title="packages/beak_core/lib/src/client/beak_client.dart"
--8<-- "packages/beak_core/lib/src/client/beak_client.dart:ensureSuccess"
```

The message is the body's `message`, or `HTTP <status>.` when the body is not a JSON object. Real decodes, from a `BeakClient` over a mock transport:

| Response | Thrown |
| --- | --- |
| `422` `{"code":"validation","fieldErrors":{...}}` | `BeakValidationException` with `fieldErrors` |
| `404` `{"code":"not_found"}` | `BeakNotFoundException` |
| `500` `{"code":"internal"}` | `BeakInternalException`, message `Internal server error.` |
| `500` `{"code":"configuration"}` | `BeakConfigurationException` |
| `502` with an HTML body | `BeakInternalException`, message `HTTP 502.` |
| `413` `{"code":"payload_too_large"}` | `BeakPayloadTooLargeException` |
| `422` with no body | `BeakValidationException`, message `HTTP 422.` |
| `400` with no Beak code | `BeakTransportException`, message `HTTP 400.` |

The status fallback maps `401`, `403`, `404`, `409`, `413` and `422` to their types, every `5xx` to `BeakInternalException` and everything else to `BeakTransportException`. So a server that failed on its own account is never reported as a configuration problem, and a proxy error page is reported as what it is, a failure that is not the caller's fault. Switch on the exception type. `BeakConfigurationException` is left for the case the server itself names: Beak is wired wrong.

Two calls change the rule for a single status. `BeakClient.getOne` returns `null` on a 404 instead of throwing. `BeakClient.discardUpload` skips a 404, so an interrupted cleanup can be retried.

The Serverpod tunnel (`packages/beak_serverpod/lib/src/tunnel_http_client.dart`) builds the same envelope for faults that never reached Beak: `401` becomes `authentication`, `403` `authorization`, `404` `not_found`, `409` `conflict`, `413` `payload_too_large`, anything else `transport`. The client rebuilds all of them as their own types.

## Failures inside a receipt

A graph commit answers `200` even when the save failed. The failure travels inside the receipt, so a retry never mistakes it for a transport error. See [REST API](rest-api.md#graph-commits) for the route and [Graph commits](../architecture/graph-commits.md) for the mechanics.

| Type | Members | Meaning |
| --- | --- | --- |
| `BeakSaveError` | `code`, `message`, `fieldErrors` | A failure safe to serialize into a receipt |
| `BeakOperationResult` | `id`, `status`, `draftId`, `resolvedId`, `table`, `record`, `error`, `reason` | One operation's outcome |
| `BeakWriteOutcome` | `applied`, `unapplied`, `unknown` | Confirmed written, confirmed not written, cannot be proven either way |
| `BeakSaveMode` | `atomic`, `staged` | One transaction, or one checkpoint per operation |
| `BeakSaveResult` | `saveId`, `mode`, `outcomes`, `rootOperationId` | The receipt. `complete`, `hasUnknown` and `identities` are derived. |

`BeakSaveError.fromException` keeps a recognized `BeakException` as is (a `BeakValidationException` keeps its `fieldErrors`) and turns anything else into code `unknown` with the message `The write outcome could not be confirmed.` Its `code` is a plain string holding the same values as `BeakException.code`.

`BeakOperationResult.reason` is a plain string too. These are the values the code sets:

| `reason` | Set by | Status | Meaning |
| --- | --- | --- | --- |
| `rejected` | server | `unapplied` | This operation carried the failure in `error` |
| `rolledBack` | server | `unapplied` | Fine on its own, undone because another operation of the atomic plan failed |
| `notStarted` | server, staged runner | `unapplied` | Placeholder before dispatch |
| `inFlight` | staged runner | `unknown` | Checkpoint written before the operation ran |
| `unsupportedBehavior` | staged runner | `unapplied` | The plan needs model behavior and the data source cannot commit atomically |
| `rejected` | `BeakFormCommitRepository` | `unapplied` | The commit call threw a typed refusal (422, 413, 401, 403, 404, 409), so the server ran no write. The error is in `error` |
| `responseUnavailable` | `BeakFormCommitRepository` | `unknown` | The commit call threw something that cannot prove nothing was written (a dropped connection, a timeout, a 5xx), so nothing is known |
| `notReceived` | `BeakFormCommitRepository` | `unapplied` | The receipt lookup answered 404 from a source that keeps receipts durably, or for a save this same page sent, so the plan never arrived |
| `receiptLost` | `BeakFormCommitRepository` | `unknown` | A reload found a pending save and the source keeps receipts in memory only, so its 404 proves nothing. The form asks the user to check and discard |
| `restoredPendingSave` | draft runtime | `unknown` | A reload found a stored snapshot of a save in flight |

A `saveId` with an `unknown` outcome is never replayed. `GET /api/commits/{saveId}` resolves it. When a receipt has to become an exception again (a single-record delete through `ModelBeakDataSource`), the first outcome error is mapped back by `code`: `validation`, `authorization`, `authentication`, `not_found`, `configuration` and `storage` keep their type, and everything else becomes `BeakConflictException`.

## Failures in the panel

View models never catch. The repository is the catch boundary and returns a `BeakResult<T>`.

```dart title="packages/beak_core/lib/src/common/beak_result.dart"
--8<-- "packages/beak_core/lib/src/common/beak_result.dart:BeakResult"
```

| Type | Members |
| --- | --- |
| `BeakOk<T>` | `value`; `isOk` is `true` |
| `BeakErr<T>` | `error` (a `BeakException`); `isOk` is `false`; `valueOrThrow` rethrows `error` |

`BeakResourceRepository` wraps each data-source call with `beakRun`:

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_run.dart:beakRun"
```

A `BeakException` becomes a `BeakErr`. Any other `Exception` is offered to `mapException` and rethrown when the mapper returns `null` or is absent. An `Error` (a programming mistake) always propagates. `BeakPanelConfig.mapException` installs the same mapper for every resource of a panel, and `BeakPanel(mapException: ...)` sets it without a config.

`BeakFormSession` exposes the most recent load or save failure as `error` (`ReadonlySignal<BeakException?>`) and the latest receipt as `saveResult` (`ReadonlySignal<BeakSaveResult?>`). `hasUnknown` is `true` while any outcome is `unknown`, and a form with an unknown outcome refuses to save again until `recover()` has resolved it.

`BeakLocalizations.authError(BeakException)` turns an authentication failure into a fixed, localized sentence (English and German) and never shows the backend's message.

## Exceptions outside the family

These are not `BeakException`s, because nothing maps them to an HTTP response.

| Type | Where | Behavior |
| --- | --- | --- |
| `BeakProjectConfigException` | `beak_cli` | `beak.yaml` cannot be read. The runner prints `beak.yaml: <message>` and exits `1`. |
| `BeakIrreversibleMigrationException` | `beak_backend` | Rolling back the baseline migration `beak introspect` writes. Carries `migration`. |
| `BeakTemplateException` | `beak_cli` | A block template in the agent files failed to render. |
| `FtpProtocolException` | `beak_storage_ftp` | Low-level FTP failure. The driver wraps it as `BeakStorageException`. |
| `UniqueConstraintException` | `worm` | Caught by the data source and the graph service and rethrown as `BeakConflictException`. |
| `ForeignKeyException`, `CheckConstraintException`, `DataException` | `worm` | Caught by the data source: a foreign key on delete is a `BeakConflictException`, the others a `BeakValidationException`. |

## Rules and limits

- Switch on `code` or on the exception type. Never parse `message`.
- Only `BeakValidationException` carries `fieldErrors`. A `BeakSaveError` also carries them, so a form can show receipt errors on the fields.
- `code` values are strings, not an enum. `BeakSaveError.code` and `BeakOperationResult.reason` are plain strings on the wire, so a client matches them with a default branch.
- Typed 500 messages, including `BeakInternalException`'s, are sent as written, except `BeakStorageException`, which is replaced by `File storage failed.` and reported to `onUnexpectedError`. Keep secrets out of the message of an exception you throw from a policy or preparer.
- `BeakClient` lets the `http` package's `ClientException` (a refused connection) propagate, and `beakRun` rethrows it unless `mapException` maps it. The panel's data source does the mapping for you: a `ClientException` or a `TimeoutException` that your `mapException` does not claim becomes a `BeakTransportException` with a generic message, so a list shows its error state instead of loading for ever.

## Source

- `packages/beak_core/lib/src/common/beak_exception.dart` defines the family.
- `packages/beak_core/lib/src/common/beak_result.dart` defines `BeakResult`, `BeakOk` and `BeakErr`.
- `packages/beak_core/lib/src/client/beak_client.dart` decodes error bodies.
- `packages/beak_core/lib/src/data/beak_commit.dart` defines `BeakSaveError`, `BeakOperationResult` and `BeakSaveResult`.
- `packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart` maps exceptions to responses.
- `packages/beak_backend/lib/src/auth/beak_policy.dart` holds `enforcePolicyDecision`.
- `packages/beak_frontend/lib/src/data/beak_run.dart` and `packages/beak_frontend/lib/src/data/beak_resource_repository.dart` are the panel's catch boundary.
- `packages/beak_serverpod/lib/src/tunnel_http_client.dart` builds envelopes for transport faults.

## Continue reading

- [REST API](rest-api.md) lists the status each route returns and the request that provokes it.
- [Results and errors](../concepts/results-and-errors.md) explains why view models never catch.
- [Auth and policies](../backend/auth-and-policies.md) covers the 401 and 403 decisions.
- [Middleware](../backend/middleware.md) places the error-mapping boundary in the request pipeline.
