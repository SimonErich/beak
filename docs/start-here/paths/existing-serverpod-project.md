---
title: An existing Serverpod project
description: Five questions that route a Serverpod 4 project to the admin app in its workspace, to the client bridge, or to neither, with the first commands of each.
type: guide
audience: [beginner, expert]
status: stable
---

# An existing Serverpod project

You have a Serverpod 4 project with tables, endpoints and sign-in, and you want an admin panel. This page does not teach either integration. It asks five things about your project and sends you to the section that does.

Serverpod keeps owning what it owns: the tables, the migrations, the scopes, the sign-in. Beak adds a panel on top. The two paths differ in where it sits.

## At a glance

| Path | Where Beak runs | What changes on your server | You give up |
| --- | --- | --- | --- |
| Admin app in your workspace | Beak's API runs inside the Serverpod server, behind one gated endpoint | One endpoint, one policy, one engine, one receipts model and its migration | Your endpoint logic does not run for admin writes; no uploads |
| Client bridge | Nowhere new: the panel calls your generated client | Nothing | Relations, atomic saves, summaries, export, server-side field permissions |
| Neither | A separate Beak app with a database of its own | Nothing | It never sees Serverpod's tables |

Two commands will not do this for you, on purpose. `beak init` refuses to run inside a Serverpod workspace, and `beak introspect` refuses a Serverpod database, because two tools that each believe they own a schema do not stay friends:

```console
$ beak introspect postgres://user:pass@localhost:5432/bookshop --dry-run
This database belongs to a Serverpod server. Beak does not connect to it; add the admin app to your Serverpod workspace instead (see the Serverpod section of the docs).
```

## Five questions

Answer them in order and stop at the first row that applies.

| Question | If yes | If no |
| --- | --- | --- |
| Can you change and redeploy the Serverpod server? | Continue | The bridge: it needs no server change |
| Do your endpoints hold rules the admin must not bypass (an audit row, a webhook, a refund check)? | The bridge: every write is one of your endpoint calls | Continue |
| Do you need atomic multi-row form saves, relations loaded with the rows, summaries or CSV export? | The admin app: only Beak's API on a database session can do these | Either fits; try the bridge first, because backing out is deleting a package |
| Do you need uploads on Serverpod-owned tables? | Neither yet: the tunnel mounts no upload routes and the bridge has no upload client | Continue |
| Does the admin need data Serverpod should never see? | A separate Beak app on its own database, which is not a Serverpod integration | Take the path from the rows above |

[Choosing an integration](../../serverpod/choosing-an-integration.md) has the full comparison matrix behind these five rows, and the reasoning for each.

## Take the admin app

You add two packages to the pub workspace: a pure Dart `<name>_beak` package with one Beak schema class per table (marked `managesSchema: false`, because Serverpod owns the schema), and a Flutter web `<name>_admin` app with a `BeakPanel`. On the server you add one gated endpoint, a deny-by-default policy and a receipts model.

Versions are strict: Serverpod exactly `4.0.3`, Dart `3.12.2` or newer, Flutter `3.44.4` or newer, and one Beak ref on every Beak package. Beak is not on pub.dev, so each package is a git or path dependency. Until `v0.9.0` is tagged the ref is a branch or a path; [Installation](../installation.md#the-release-is-not-tagged-yet) explains why.

Read in this order:

1. [Admin app in your workspace](../../serverpod/admin-app/index.md) for what the workspace looks like afterwards.
2. [Setting up the admin app](../../serverpod/admin-app/setup.md), a tutorial from an empty schema package to a signed-in panel.
3. [Limits and next steps](../../serverpod/admin-app/limits-and-next-steps.md), before you plan on it. The path is a proof on one example workspace, not a product.

The working reference is `examples/serverpod`, a Serverpod 4.0.3 workspace with an admin for `Author` and `Book`.

## Take the bridge

The panel calls your generated client, so there is no server work. Add `beak_serverpod` and `beak_core` to the package that holds your panel, and `beak_serverpod_generator` as a dev dependency. Generate Serverpod's client first, resolve packages, then generate the resources:

```console
$ dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
Generated /home/me/consumer/lib/beak/entry_resources.g.dart
```

`beak init` cannot wire this for you, so you add the dependencies, build the resources and mount a `BeakPanel` by hand. Read in this order:

1. [Client bridge](../../serverpod/bridge/index.md) for what it is and what it cannot do.
2. [Endpoint conventions](../../serverpod/bridge/endpoint-conventions.md), to check that your endpoints fit the generator.
3. [Generating bridge resources](../../serverpod/bridge/generator.md) or [Bridge resources](../../serverpod/bridge/resources.md), for the generated or the hand-written binding.

Domain errors from your endpoints reach the panel only through `BeakPanel(config: BeakPanelConfig(mapException: ...))`; the `BeakPanel(...)` shorthand has no `mapException`.

## Sign-in for both

Both paths share Beak's login, registration and recovery screens over Serverpod's email sign-in, through `ServerpodAuthAdapter`. The admin app also needs the `beak.admin` scope on the account, which you grant with a script. [Authentication and scopes](../../serverpod/authentication.md) covers scopes, token lifetimes and revocation.

## Rules and limits

- **One panel takes one path.** A `BeakPanel` given a `dataSource:` (the admin path) routes every resource to it. Bridge resources bring their own source. Use two panels or pick one.
- **The admin app needs a policy.** There is no allow-all default on that path: the engine is built with a `BeakPolicies` you write, deny by default.
- **Serverpod stays the schema owner.** Never run `beak migrate` against Serverpod's database from a Beak app of its own, and never give Beak the database URL of a Serverpod project.
- **Versions do not float.** The admin app tests against Serverpod 4.0.3 only. The break between the 4.0 beta and 4.0.x is on [Version compatibility](../../serverpod/versions.md).
- **Uploads are not available** on either path, so a file or image column on a Serverpod-owned table has nowhere to go.
- **The bridge is the older and narrower path.** It is covered by unit tests and a generator run against fixtures, not by a running Serverpod server.

## Verify it

You are on the right path when the first check below passes.

| Path | Check |
| --- | --- |
| Admin app | In the `<name>_beak` package, `beak prepare` writes the `*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else (it recognises a package of schema classes). In the workspace, Serverpod refuses an unauthenticated `beakAdmin.dispatch` before any Beak code runs, and the panel lists your tables once the account has the `beak.admin` scope. |
| Bridge | The generator prints `Generated <path>`, and `dart analyze` on the panel package is clean. |

[Troubleshooting](../../serverpod/troubleshooting.md) maps error messages to causes.

## Reference

| Section | Pages |
| --- | --- |
| Overview | [Serverpod](../../serverpod/index.md), [Choosing an integration](../../serverpod/choosing-an-integration.md), [Version compatibility](../../serverpod/versions.md) |
| Admin app | [Admin app in your workspace](../../serverpod/admin-app/index.md), [How it works](../../serverpod/admin-app/how-it-works.md), [Setup](../../serverpod/admin-app/setup.md), [Limits](../../serverpod/admin-app/limits-and-next-steps.md) |
| Bridge | [Client bridge](../../serverpod/bridge/index.md), [Bridge resources](../../serverpod/bridge/resources.md), [Generator](../../serverpod/bridge/generator.md), [Endpoint conventions](../../serverpod/bridge/endpoint-conventions.md) |
| Shared | [Authentication and scopes](../../serverpod/authentication.md), [Troubleshooting](../../serverpod/troubleshooting.md) |

## Continue reading

- [Choosing an integration](../../serverpod/choosing-an-integration.md): the comparison matrix behind the five questions.
- [Setting up the admin app](../../serverpod/admin-app/setup.md): the tutorial for the first path.
- [Client bridge](../../serverpod/bridge/index.md): the section for the second.
- [An existing backend](existing-backend.md): the general version of the bridge, for backends that are not Serverpod.
