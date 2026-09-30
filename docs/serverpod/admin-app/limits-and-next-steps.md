---
title: Limits and next steps
description: What the Serverpod admin app proof does not cover yet, why, the workaround that exists today and the tests that show what is proven.
type: guide
audience: [expert]
status: stable
---

# Limits and next steps

The admin app is a proof on two tables. This page lists what it does not do, with the reason and the workaround for each, so you can decide whether to build on it before you have built on it.

## At a glance

Proven by tests on the example: the gate, deny-by-default policy, reads and writes on Serverpod's own database, the server-only column, graph-commit replay and receipts, the worm and Beak data-source contracts on `ServerpodSessionAdapter`, and the panel against a fake `dispatch`.

Not proven, or missing: uploads, business rules in the example, a drift check, deployment, measured throughput, and any sign-in other than the email provider with JWT.

## Rules and limits

| Limit | Why | Workaround today |
| --- | --- | --- |
| Revoking access is bounded by the access-token lifetime, 10 minutes by default | The gate reads scopes from the access token. `revoke` removes the scopes and revokes every token of the user, but an access token that was already issued stays valid until it expires | Set a shorter `accessTokenLifetime` on `JwtConfigFromPasswords` (a Serverpod option; the example leaves the default). The price is more refresh calls |
| No uploads | The engine passes no storage to Beak's API router, so upload routes are not mounted, and the tunnel carries text only | Keep file columns out of the mirrored schema classes. Use Serverpod's own file handling and show the URL as text |
| No drift check | The Beak schema classes are hand-written mirrors of the `.spy.yaml` models. The example's test compares column names and enum values, nothing more: not types, nullability, length or uniqueness. There is no runtime check and no banner in the panel | Extend the mirror test, run it in CI, and treat a red `dart test` in the server as the alarm |
| Endpoint logic does not run for admin writes | Beak writes rows directly through SQL on the session. Anything your `book.create` endpoint does besides inserting (audit rows, cache flushes, webhooks) is skipped | `preparePlan` and `graphOnly` on `BeakServerpodEngine` are covered by the package's own unit tests. `finalizePlan` is passed through to Beak's router and no test on this path exercises it. The example uses none of them, and the engine has no outbox parameter or delivery loop ([durable effects](how-it-works.md#durable-effects-and-pruning)). Or keep such tables off the admin |
| Receipts are never pruned | `beak_commit_receipt` keeps one row per form save, nothing deletes it, and the engine does not hand out the commit service, so `BeakGraphCommitService.pruneReceipts` is out of reach on this path | Delete old rows with Serverpod's own model from a future call or a script: `BeakCommitReceipt.db.deleteWhere(session, where: (t) => t.createdAt < cutoff)` (the example's endpoint test does it). A pruned save id is a new save, so keep the cutoff longer than any retry window |
| The panel shares your app's process and pool | Beak's statements run on the request's `session.db`. An expensive query or export competes with real traffic | Each statement times out after 30 seconds (`statementTimeoutInSeconds` on the engine). An export is built in memory and returned as one string |
| Request bodies are capped at 512 KiB | The template's `maxRequestSize` applies to every Serverpod call, and every panel call is one. A larger request fails with 413 | Raise `maxRequestSize` in your config, for the whole server |
| The example's Docker build is not supported | The template's Dockerfile copies only `bookshop_server` into a minimal workspace. The server now depends on `bookshop_beak`, and the example reaches Beak's packages through `../../../packages`, which is outside that context | In your workspace Beak comes from git, but `<name>_beak` still has to be copied into the image and listed in the Dockerfile's `workspace:`. Not tried here |
| Deployment of the admin app itself is undocumented | The example runs the admin with `flutter run`. Serving its web build from the Serverpod server or from a separate host has no test and no page | Serve `flutter build web` output the way you serve any Flutter web app; nothing in Beak stops you |
| Beak is a git or path dependency | Beak is not on pub.dev. `pub get` fetches it from GitHub, and every Beak package must use the same ref | Pin one `ref` in every pubspec, and change it in one commit |
| Exact Serverpod pins | The server and the app pin `serverpod*` to 4.0.3. Beak's own constraints are wider (`>=4.0.3 <5.0.0`), so the pin is yours to keep | Bump every `serverpod*` package together, then run both test suites |
| One sign-in path is tested | Email with JWT. The example has no cookie mode, no server-side sessions and no other provider, and `bin/beak_admin.dart` looks accounts up through the email provider | See [Authentication and scopes](../authentication.md) |
| One panel takes one path | A `dataSource:` on the panel replaces the sources that models bring, so tunnel resources and bridge resources cannot share a panel | Use two panels, or pick one path |
| Nothing was measured under load | The tests check behavior, not throughput | Measure your own query mix before you rely on it |

## Verify it

Every proven claim above has a test. Run the suites without starting a server:

```console
cd examples/serverpod/bookshop_server && dart test    # embedded Postgres, no Docker
cd examples/serverpod/bookshop_admin && flutter test  # widget tests, fake dispatch
```

| Claim | Where it is proven |
| --- | --- |
| Anonymous is 401, no `beak.admin` is 403, even with `Scope.admin` | `test/integration/beak/beak_admin_endpoint_test.dart`, and the engine's own 403 in `packages/beak_serverpod_server/test/beak_serverpod_engine_test.dart` |
| `beak.admin` alone grants nothing, nobody deletes, unregistered tables are 404 | the same file |
| A commit replays by save id and leaves one receipt, and old receipts can be pruned through the typed model | the same file |
| The supplier cost is in no response, export or receipt, and cannot be written | `test/integration/beak/beak_admin_security_test.dart` |
| Paths outside `/api` and forged credential headers are refused | the same file |
| worm's adapter contract and Beak's data-source contract pass on `ServerpodSessionAdapter` | `session_adapter_contract_test.dart` and `session_adapter_data_source_contract_test.dart` |
| Beak columns exist in the Serverpod tables, the enum matches | `test/beak_models_match_serverpod_test.dart` |
| Books and Authors load, filter and save through the tunnel | `bookshop_admin/test/admin_panel_test.dart` |
| Sign-in without the scope stays on the sign-in screen | `bookshop_admin/test/admin_login_test.dart` |

One more test needs a running server and stays out of `flutter test` on purpose: `test_live/admin_flow_test.dart` signs up by email, grants and revokes access with the script, and replays a commit. Its header comment has the commands.

## Reference

What to do next, in the order it pays off:

1. Write your own `BookshopScopes` and policy for your tables. Name every model and every operation you allow.
2. Decide the access-token lifetime. It sets how long a revoked admin keeps working.
3. Extend the mirror test to cover what your tables use: types, nullability, uniqueness.
4. Move endpoint logic that admin writes must run into a `preparePlan` or into model behavior, and test it the way the example tests its policy.
5. Plan the deployment: the image, the admin's web build, the `maxRequestSize`.

If the admin app is more than you need, the [client bridge](../bridge/index.md) changes nothing on the server. The comparison is on [Choosing an integration](../choosing-an-integration.md).

## Continue reading

- [Client bridge](../bridge/index.md): the path that changes nothing on the server.
- [Authentication and scopes](../authentication.md): grants, revokes and token lifetimes in detail.
- [Troubleshooting](../troubleshooting.md): the error messages you will meet on the way.
