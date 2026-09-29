---
title: Troubleshooting
description: Symptom, cause and fix for the errors of the Serverpod admin app and client bridge, from 401 and 403 at the gate to bridge query refusals.
type: reference
audience: [expert, agent]
status: stable
search:
  boost: 2
---

# Troubleshooting

Look up the message or the symptom. Messages are quoted as the code writes them. Where a row says "likely", the cause is the usual one and was not reproduced.

## Import

The messages come from these libraries. The admin app path uses the first three, the bridge the last two:

```dart
import 'package:beak_serverpod_server/beak_serverpod_server.dart';
import 'package:beak_serverpod_flutter/beak_serverpod_flutter.dart';
import 'package:beak_serverpod/wire.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:beak_serverpod_generator/beak_serverpod_generator.dart';
```

## Summary

### The gate and the tunnel (admin app)

| Symptom or message | Cause | Fix |
| --- | --- | --- |
| 401 from `beakAdmin.dispatch`; the panel shows `Your session has ended. Sign in again.` | No session, or an expired one. Serverpod's `ServerpodUnauthenticatedException`, seen by the client as `ServerpodClientUnauthorized` | Sign in. If it repeats right after sign-in, check that `main` sets `..authSessionManager = sessionManager`, awaits `client.auth.initialize()`, and that the server has `JwtRefreshEndpoint` |
| 403 from `beakAdmin.dispatch`; the panel shows `This account may not use the admin.` | Signed in, but the token has no `beak.admin` scope. Serverpod's `ServerpodInsufficientAccessException`, seen as `ServerpodClientForbidden`. `Scope.admin` does not count | `dart run bin/beak_admin.dart grant <email>`, then sign in again |
| Correct password, back on the sign-in screen with `The account cannot access this panel.` | The identity resolver returned `canAccessPanel: false`: the token has no `beak.admin` | The same grant, then sign in again |
| Granted, still refused | The token was issued before the grant, and scopes are copied in when a token is issued | Sign out and in |
| Revoked, still works for a few minutes | An access token issued before the revoke stays valid until it expires, 10 minutes by default | Shorten `accessTokenLifetime`. See [Authentication and scopes](authentication.md) |
| Every table answers 403 with code `authorization` | `beak.admin` opens the tunnel and grants nothing. The policy has no rule for the model, or the role does not match | Add a `BeakModelRules` for the model. `BeakAccess.role` takes the scope's name, for example `bookshop.staff` |
| 404 `No handler for <METHOD> <path>.` | The path is outside `/api`, is under `/api/auth`, or names a table that is not in the registry. `beak_commit_receipt` and Serverpod's own tables are never there | Register the model in `<name>_beak`, run `beak prepare`, and pass `buildBeakRegistry()` to the engine |
| 400 `Malformed Beak tunnel request.` | The string is not an envelope. Something other than the tunnel client called `dispatch` | Go through `serverpodBeakDataSource` or `ServerpodBeakHttpClient` |
| 400 `Unsupported Beak tunnel version <n> (this server speaks 1).` | The admin app and the server run different Beak refs | Use one ref for every Beak package |
| 401 `Sign in to use the Beak admin.` from the engine | The engine sits behind an endpoint without `BeakAdminGate` | Add `with BeakAdminGate` to the endpoint class |
| 403 `Not allowed to use the Beak admin.` | Your `principal` resolver returned `null` | Return a `BeakPrincipal`, or throw `BeakAuthorizationException` with your own message |
| 413 `The request is larger than the server accepts.` | The request body is above `maxRequestSize` (512 KiB in the template's config) | Send less, or raise `maxRequestSize` for the whole server |
| 422 on a create, patch or commit | The request carries a column the Beak model does not declare, for example the server-only column | Expected. Do not model the column |
| A timeout on CSV export, with the 20 second default | The export is one call and Serverpod's `connectionTimeout` defaults to 20 seconds | `Client(url, connectionTimeout: const Duration(seconds: 60))`, as `main` does |
| `StateError`: `No Serverpod Session in this zone. Beak database calls must run inside BeakServerpod.runInSession(session, ...).` | A `ServerpodSessionAdapter` was used outside `dispatch` | Wrap the call in `BeakServerpod.runInSession`, or build the adapter with `ServerpodSessionAdapter.forSession(session)` |
| `UnsupportedOperationException`: `Serverpod owns the schema: change it in a *.spy.yaml file and create a migration with serverpod create-migration.` | Code asked the adapter to create, alter or introspect tables, for example a Beak migration | Do not run Beak migrations on this path. Change the `.spy.yaml` and run `serverpod create-migration` |
| Reads work, form saves fail with a server error naming `beak_commit_receipt` (likely) | The receipts table is missing: the model file was not copied, or its migration was not created or not applied | Copy the model file, run `serverpod generate` and `serverpod create-migration`, start the server with `--apply-migrations` |

### Build, run and tests (admin app)

| Symptom or message | Cause | Fix |
| --- | --- | --- |
| `client.beakAdmin` does not exist | `serverpod generate` did not see the endpoint | Put the class under the server's `lib/`, extend `Endpoint`, and keep the method public with `Session` first: `dispatch(Session session, String request)` |
| `beak prepare` in `<name>_beak` creates `bin/`, `lib/main.dart` or `lib/beak/app.g.dart` | The CLI is older than this release | Reactivate the CLI at your Beak ref |
| The server starts with `dart bin/main.dart` and email sign-in fails (likely) | Only `dart run` builds the Argon2 native asset the email sign-in needs | `dart run bin/main.dart --apply-migrations`, and the same for `bin/beak_admin.dart` |
| `dart test`: `Beak declares columns the Serverpod table does not have` | A Beak column is not a physical column. Serverpod's physical columns keep their camelCase | Fix the name, or set `columnName: 'priceInCents'` |
| `dart test`: the enum lists differ | The Dart enum in `<name>_beak` and the `.spy.yaml` enum have different values | Make the lists identical. Keep `serialized: byName` |
| `dart test`: the supplier cost is modelled | A server-only column got a Beak field | Remove the field |
| `pub get` cannot solve the versions | The `serverpod*` pins differ, or Dart and Flutter are below 3.12.2 and 3.44.4 | [Version compatibility](versions.md) |
| `bin/beak_admin.dart` prints its `usage:` line and exits with 64 | Wrong arguments | Pass `grant` or `revoke`, then one email |
| `bin/beak_admin.dart`: `No email account for <email>. Sign up first.`, exit 1 | The account does not exist yet | Register in the admin, then run the script |

### Panel and sign-in messages

| Message | Cause | Fix |
| --- | --- | --- |
| `External authentication requires bound models or a data source.` | The panel has an auth adapter, and a resource brings no data source of its own, with no `dataSource:` on the panel | On the admin path, pass `dataSource: serverpodBeakDataSource(client.beakAdmin.dispatch)` |
| The panel ignores `httpClient:` | With an external authentication adapter the panel registers no HTTP client of its own | Use `dataSource:` |
| `Invalid credentials.` | Any failed login except rate limiting: the adapter shows one message for a wrong password and an unknown account alike | Check the email and the password |
| `Too many sign-in attempts.` | Serverpod's rate limit for login | Wait |
| `Too many verification attempts.` | Serverpod's rate limit for registration or recovery | Wait |
| `The verification request or password was rejected.` | Wrong code, expired request, or a password Serverpod refuses | Start the flow again |
| `The device session is no longer valid.` | Serverpod answered 401 to a call of the auth adapter | Sign in |
| `Access denied.` | Serverpod answered 403 to a call of the auth adapter | The account lacks a scope |
| `Authentication transport failed.` | An error nothing mapped. Pass an `exceptionMapper` for your own domain exceptions | Map it |
| `Start a new email verification request.` | A registration or recovery step ran with no open request | Begin again from the email step |

### The bridge at runtime

| Message | Kind | Cause | Fix |
| --- | --- | --- | --- |
| `Unsupported query for resource "<key>".` | `BeakConfigurationException` | A filter beyond AND of equalities, a second sort, a sort or search the endpoint has no field for, relation loads, or archived rows without `includeArchived` | Remove it from the screen, or bind an explicit `query:` callback |
| `Ambiguous or missing query field "<name>".` | `BeakConfigurationException` | A filter or sort name resolves to several paths, or none | Pass `sortFields`, or rename the descriptor |
| `The endpoint page origin must be configured as zero or one.` | `BeakConfigurationException` | `firstPage` is neither 0 nor 1 | Use 0 or 1 |
| `Resource "<key>" does not support <operation>.` | `BeakValidationException` | The operation was never bound: create, update, delete, forceDelete, restore, batchGet, aggregate, editValues, attach or detach | Bind it, or leave the action out of the screen |
| `Unknown resource "<key>".` | `BeakConfigurationException` | A request named a resource no source registered | Check the `resource:` key |
| `Invalid or duplicate resource "<key>".` | `BeakConfigurationException` | Two resources share a key, or a key is empty | Use unique keys |
| `Unsupported aggregate.` | `BeakConfigurationException` | An aggregate other than a plain count | Bind your own `aggregate:` |
| `This data source does not support summaries.` | `BeakConfigurationException` | A summary block on a bridge resource | Remove the block, or use the admin app |
| `This data source does not support CSV exports.` | `BeakConfigurationException` | Export on a bridge resource | Remove the action, or use the admin app |
| `Expected a valid <type> value.` | `BeakValidationException` | A codec was given a value of another type | Check the column's Dart type |
| `The record no longer exists.` | `BeakNotFoundException` | The edit prefill read a row the endpoint no longer returns | Refresh the list |
| `Configure an edit projection for command field "<field>".` | `BeakConfigurationException` | The edit form has a field no read column matches | Give `editValues`, or use the generated `editInput` helper |

Generator messages (`Companion generation failed: ...`) are listed with their causes on [Endpoint conventions](bridge/endpoint-conventions.md).

## Source

| Message family | File |
| --- | --- |
| Gate, tunnel, engine | `packages/beak_serverpod_server/lib/src/beak_serverpod_engine.dart`, `beak_admin_gate.dart`, `beak_tunnel_path.dart`, `beak_serverpod.dart` |
| Wire and envelope | `packages/beak_serverpod/lib/src/wire.dart`, `tunnel_http_client.dart` |
| Tunnel faults and sign-in | `packages/beak_serverpod_flutter/lib/src/serverpod_beak_http_client.dart`, `serverpod_auth_errors.dart`, `serverpod_auth_adapter.dart` |
| Bridge queries and operations | `packages/beak_serverpod/lib/src/query.dart`, `resource.dart`, `data_source.dart`, `field.dart` |
| Panel startup | `packages/beak_frontend/lib/src/di/beak_locator.dart`, `packages/beak_frontend/lib/src/data/model_beak_data_source.dart` |
| Grant script | `examples/serverpod/bookshop_server/bin/beak_admin.dart` |

## Continue reading

- [Serverpod](index.md): the two paths and the page that covers each.
- [Reference](../reference/index.md): every annotation, field type, rule, block, option, REST route, CLI command and exception.
- [Version compatibility](versions.md): pins, floors and the 4.0 beta break.
