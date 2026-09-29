---
title: Serverpod admin
description: "A card for the Serverpod example: a bookshop workspace whose Beak admin runs behind one gated endpoint, with its tests and its limits."
type: example
audience: [expert, agent]
status: stable
---

# Serverpod admin

This is the short version. The bookshop example is a Serverpod 4 workspace whose admin app is Beak: the panel talks to one endpoint method on your Serverpod server, and Beak's API runs behind it on Serverpod's own database. The [Serverpod section](../serverpod/index.md) owns the walkthrough, the request path and the limits. This page tells you what is in the example, how to run its tests and which file to open first.

## At a glance

| | |
| --- | --- |
| Domain | A bookshop, "Dog-Eared Books" |
| Models | 2 Serverpod tables, `author` and `book`, mirrored by 2 Beak schema classes |
| Packages | 5: `bookshop_server`, `bookshop_client`, `bookshop_flutter` (from `serverpod create`), plus `bookshop_beak` and `bookshop_admin` |
| Versions | Serverpod 4.0.3, Dart 3.12.2 or newer, Flutter 3.44.4 or newer |
| API port | 8080 (Serverpod's API server). The admin runs on web port 8095 |
| Auth | Serverpod's email login. The `beak.admin` scope opens the endpoint, and `bookshop.staff` grants reads and writes |
| Database | Serverpod's Postgres, embedded in development, no Docker |
| Panel bootstrap | Authored: `BeakPanel` over `serverpodBeakDataSource(dispatch)` |
| Tests | 146 on the server, 6 on the admin |
| Read it if | You have a Serverpod project and want an admin without a second server |

## Run it

You need Dart 3.12.2 or newer and Flutter 3.44.4 or newer. The full sequence is in the example's README:

```console
# in examples/serverpod: resolve the whole workspace
dart pub get
cp bookshop_server/config/passwords.example.yaml bookshop_server/config/passwords.yaml

# terminal 1: the server, on an embedded Postgres
cd bookshop_server && dart run bin/main.dart --apply-migrations

# terminal 2: the admin
cd bookshop_admin && flutter run -d chrome --web-port 8095

# terminal 3: after "Create account" in the admin, let that account in
cd bookshop_server && dart run bin/beak_admin.dart grant you@example.com
```

Use `dart run`, not `dart bin/main.dart`: only `dart run` builds the native asset the email login needs. In development the server prints the registration code to its log ("Registration code for you@example.com: ..."). Sign in again after the grant, because the scopes are read from the token issued at sign-in.

The commands that start the server and the browser are the README's. The workspace resolution and both test suites below were run for this page, without starting a server.

## Tour

Three files carry the idea. The endpoint is one method, and the mixin in front of it answers 401 or 403 before any Beak code runs:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/beak_admin_endpoint.dart:BeakAdminEndpoint"
```

The policy is deny by default. Holding `beak.admin` opens the tunnel and grants nothing:

```dart title="examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart"
--8<-- "examples/serverpod/bookshop_server/lib/src/beak/bookshop_policy.dart:bookshopPolicy"
```

Nobody may delete. A rule that is not written is a rule that is closed. The panel on the other end is an ordinary `BeakPanel` with a different data source:

```dart title="examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/src/bookshop_admin.dart:bookshopAdminPanel"
```

`serverpodBeakDataSource(dispatch)` carries every panel request through the generated `client.beakAdmin.dispatch`. The resources are the same `BeakResource` classes you would write anywhere else:

```dart title="examples/serverpod/bookshop_admin/lib/resources/book_resource.dart"
--8<-- "examples/serverpod/bookshop_admin/lib/resources/book_resource.dart:BookResource"
```

One column never reaches the panel. `book.supplierCostInCents` is `scope=serverOnly` in the Serverpod model, so it is not in the generated client, and the Beak schema class does not declare it. It appears in no response, no export and no stored receipt, and a client cannot write it.

Follow one request from the panel to the database in [How the admin app works](../serverpod/admin-app/how-it-works.md), or build the same thing in your workspace with [Setting up the admin app](../serverpod/admin-app/setup.md).

## Where things are

| Path | Role |
| --- | --- |
| `bookshop_server/lib/src/catalog/*.spy.yaml` | The Serverpod models. You edit these, Serverpod generates the rest |
| `bookshop_server/lib/src/beak/` | The endpoint, the engine, the policy, the scopes and the receipts model |
| `bookshop_server/bin/beak_admin.dart` | `grant` and `revoke` for the `beak.admin` and `bookshop.staff` scopes |
| `bookshop_beak/lib/models/` | Hand-written Beak schema classes, one per table, `managesSchema: false` |
| `bookshop_admin/lib/` | `main.dart`, the panel in `src/bookshop_admin.dart`, one resource per table |
| `bookshop_client/`, `bookshop_server/lib/src/generated/` | Generated by Serverpod. Never edit |
| `bookshop_flutter/` | The template's app, unchanged |

## Features shown

| Feature | File | Docs page |
| --- | --- | --- |
| One gated endpoint carrying Beak's API | `bookshop_server/lib/src/beak/beak_admin_endpoint.dart` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Deny-by-default policy on Serverpod scopes | `bookshop_server/lib/src/beak/bookshop_policy.dart` | [Authentication and scopes](../serverpod/authentication.md) |
| A server-only column | `bookshop_server/lib/src/catalog/book.spy.yaml` | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Schema classes mirroring Serverpod models | `bookshop_beak/lib/models/book.dart` | [Setting up the admin app](../serverpod/admin-app/setup.md) |
| A panel over the tunnel with Serverpod sign-in | `bookshop_admin/lib/src/bookshop_admin.dart` | [Authentication and scopes](../serverpod/authentication.md) |
| Graph commits with receipts in a Serverpod-owned table | `bookshop_server/lib/src/beak/` | [Graph commits](../architecture/graph-commits.md) |
| Data-source contracts on `ServerpodSessionAdapter` | `bookshop_server/test/integration/beak/` | [The data source seam](../architecture/data-source-seam.md) |

The other Serverpod path, the frontend-only bridge for an existing app that keeps its own endpoints, has no example of its own. It is documented in [Client bridge](../serverpod/bridge/index.md), and [Choosing an integration](../serverpod/choosing-an-integration.md) compares the two.

## Tests

```console
cd examples/serverpod/bookshop_server && dart test     # embedded Postgres, no Docker
cd examples/serverpod/bookshop_admin && flutter test   # widget tests, fake dispatch
```

The server suite ran 146 tests and the admin suite 6 (2026-09-29). All passed.

| Suite | What it proves |
| --- | --- |
| `beak_admin_endpoint_test.dart` | Anonymous is 401, no `beak.admin` is 403, `beak.admin` alone grants nothing, nobody deletes, a commit replays by save id |
| `beak_admin_security_test.dart` | The supplier cost is in no response, export or receipt and cannot be written. Forged credential headers are refused |
| `session_adapter_contract_test.dart`, `session_adapter_data_source_contract_test.dart` | worm's adapter contract and Beak's data-source contract pass on Serverpod's database |
| `beak_models_match_serverpod_test.dart` | Every Beak column exists in the Serverpod table, and the format enum matches |
| `admin_panel_test.dart`, `admin_login_test.dart` | Tables, filters and the form work through a fake dispatch, and an account without the scope stays on the sign-in screen |

`bookshop_admin/test_live/admin_flow_test.dart` needs a running server and its log, so `flutter test` leaves it out. It signs up by email, grants and revokes access, creates and edits rows and replays a commit. Its header comment has the commands.

## Limits

- Two tables. No uploads, no business rules, no graph-only models, no outbox.
- The Beak schema classes are written by hand. A test compares column names and enum values, nothing more, so a type or nullability drift is yours to catch.
- Revoking access takes effect when the access token expires, 10 minutes by default.
- The template's Dockerfile does not build this workspace. The example reaches Beak's packages by path, outside the Docker context.
- Nothing was measured under load. Beak's queries run on your server's connection pool.

The full list, with reasons and workarounds, is [Limits and next steps](../serverpod/admin-app/limits-and-next-steps.md).

## Continue reading

- [Serverpod](../serverpod/index.md): both integration paths and how to choose.
- [Setting up the admin app](../serverpod/admin-app/setup.md): the same workspace, built step by step.
- [Feature map](feature-map.md): every example against the feature it shows.
- [Examples](index.md): the other four examples.
