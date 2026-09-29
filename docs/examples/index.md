---
title: Examples
description: Five runnable Beak projects compared by domain, models, ports, auth and run command, with a guide to which one to read for what you are building.
type: index
audience: [beginner, expert, agent]
status: stable
---

# Examples

The repository ships five projects you can run. Every code snippet in this documentation comes from one of them, from files that compile and are tested, so an example page is also a map of where to look when the docs say "see the shop".

## The examples at a glance

| Example | Domain | Models | Ports (API, panel) | Auth | Highlights | Run |
| --- | --- | --- | --- | --- | --- | --- |
| [Quickstart scaffold](quickstart.md) | Notes | 1 | 8080, chosen by `flutter run` | None | The output of `beak create`, with generated wiring and a generated panel | `beak migrate`, `beak dev` |
| [Clean shop](clean-shop.md) | Catalog, orders, invoices | 20 (11 resources) | 8080, 3000 | None | Exact money, named invoice actions, wizards from shared sections, a server-side preparer, custom pages | `beak migrate`, `beak seed`, `beak dev` |
| [Foodio admin](foodio.md) | Company food ordering | 26 (14 resources) | 8081, 3002 | None | Composed lists, saved views, a five-step wizard, durable effects, a custom theme, 48,213 orders | `cp .env.example .env`, then as the shop |
| [Showcase](showcase.md) | An aviary | 14 (4 resources, 12 pages) | 8082, 3003 | None | All 13 column kinds, all 4 relationship kinds, every block type, exhaustiveness tests | `beak migrate`, `beak seed`, `beak dev` |
| [Serverpod admin](serverpod-admin.md) | A bookshop | 2 tables | 8080, 8095 | Serverpod email sign-in and scopes | An admin app inside a Serverpod 4 workspace, one gated endpoint, deny-by-default policy | The README's four steps |

Three of the five use API port 8080, so run one at a time or move one with the `PORT` environment variable (`PORT=8090 beak dev` overrides the port in `beak.yaml` too). The panel finds its API through `BEAK_API_BASE_URL`, a `--dart-define` at `flutter run`.

The four projects without Serverpod have no login on purpose. They are local demonstrations, and their APIs answer every request from every origin. Do not put one on a network you do not control.

## Which one to read

| You are... | Start with | Then |
| --- | --- | --- |
| New to Beak and want to see the smallest project | [Quickstart scaffold](quickstart.md) | [Clean shop](clean-shop.md) |
| Building a normal admin with related records | [Clean shop](clean-shop.md) | [Feature map](feature-map.md) for the rest |
| Building a designed panel or a workflow with real invariants | [Foodio admin](foodio.md) | [Clean shop](clean-shop.md) for the simpler version of each idea |
| Looking for one specific column, relationship or block | [Showcase](showcase.md) | [Feature map](feature-map.md) |
| Adding an admin to a Serverpod project | [Serverpod admin](serverpod-admin.md) | [Serverpod](../serverpod/index.md) |
| An agent asked to copy a pattern | [Feature map](feature-map.md) | The example's `AGENTS.md` and `README.md` |

## Running any of them

Every example is a Flutter package in `examples/`, and the steps are the same apart from the last one:

```console
cd examples/<folder>
flutter pub get
beak migrate      # creates the SQLite file and the tables
beak seed         # optional: examples with seeders fill demo data
beak dev          # regenerates the wiring and serves the API
```

`beak dev` prints the second command, `flutter run -d chrome`, which you run in another terminal. `beak` is the CLI from `packages/beak_cli`. From a checkout, `dart run packages/beak_cli/bin/beak.dart <command>` runs the same thing, and [Installation](../start-here/installation.md) shows how to put it on your path.

Each example has a `README.md` and an `AGENTS.md` next to its `pubspec.yaml`. The README is the author's own run and test notes, and the tour pages here quote it where it matters. The `AGENTS.md` is the block Beak keeps in step with your Beak version, plus the conventions of that project.

Numbers on the tour pages (models, resources, tests) were counted against the working tree on 2026-09-29.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| See what `beak create` writes and which files you own | [Quickstart scaffold](quickstart.md) | One model, file by file, with real command output |
| Read the teaching example end to end | [Clean shop](clean-shop.md) | Exact money, invoice actions, forms as wizards and tabs, a preparer, custom pages, tests |
| See a designed application with real business rules | [Foodio admin](foodio.md) | Composed lists, a wizard, named actions, durable effects, a custom theme |
| Find a working example of a column, relationship or block kind | [Showcase](showcase.md) | The 13 column kinds, 4 relationship kinds, every block and the tests that keep them complete |
| Run Beak inside a Serverpod 4 workspace | [Serverpod admin](serverpod-admin.md) | A short card: the gated endpoint, the policy, the tests, the limits |
| Look up which file demonstrates a feature | [Feature map](feature-map.md) | 106 rows: feature, example, file and docs page |

## Continue reading

- [Quickstart scaffold](quickstart.md): the smallest project, and the one to open first.
- [Clean shop](clean-shop.md): the example most of the docs quote.
- [Feature map](feature-map.md): the shortest route from a feature name to a file.
- [Tutorial](../tutorial/index.md): build the first resources of the shop yourself.
