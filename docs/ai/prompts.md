---
title: Prompt recipes
description: Paste-ready prompts for starting an agent on a Beak project and for each workflow skill, with the evidence to demand before a task counts as done.
type: ai
audience: [agent]
status: stable
search: {boost: 2}
---

# Prompt recipes

For coding agents and the people who brief them. Humans: see [Recipes](../recipes/index.md). Each prompt below is written to be pasted whole. It names the docs to read first, states the result you can observe, and lists the output the agent must show. An agent that reports "done" without that output has not finished.

## Rules

- MUST name the observable result, not the mechanism. "A dependent profile must belong to the selected customer" is a result. "Add a validator" is a guess at a mechanism.
- MUST tell the agent where the docs are: `.dart_tool/beak/docs/ai-index.md`. Run `beak docs` first when the folder is missing.
- MUST ask for command output, not a summary of it. The evidence lists below name the commands.
- MUST separate the parts. A new field, a rule on it and a screen for it are three tasks with three rows in the [Task map](task-map.md). One prompt may hold all three when it says so.
- NEVER ask for "everything at once" in a project with no tests. Ask for the test first.
- NEVER paste Beak signatures into a prompt from memory. Point at the file (`examples/clean_beak_config/...`) and let the agent read it.
- MUST state which bootstrap the project uses when the task touches `lib/main.dart`. Generated projects do not edit it, authored projects do.
- Until the `v0.9.0` tag exists, a plain `beak create` cannot resolve. Add "create with `--beak-path <absolute path of the Beak checkout>`" to any new-project prompt, as [Installation](../start-here/installation.md) explains.

## The skeleton

Every prompt in this page is this skeleton with the blanks filled:

```text
Task: <one sentence, the observable result>.
Read first: .dart_tool/beak/docs/ai-index.md, then the Task map row for this task.
Scope: <files or resources this may touch, and what it must not touch>.
Rules: follow the Rules for agents page. No string field references, no dynamic, no Material.
Evidence: show the output of <commands>. Show the test that fails without the change.
```

## Starting situations

### A new project

```text
Task: create a Beak admin panel for a bookshop with Author and Book (a book belongs to an author; title is required and at most 200 characters; price is exact money in EUR).
Read first: .dart_tool/beak/docs/ai-index.md, then the Task map rows "Create a project with an authored panel", "Scaffold a resource with its model", "Store money exactly" and "Relate two models".
Create it with `beak create bookshop --authored --beak-path <absolute path of the Beak checkout>`, SQLite for now.
Scope: the new project only.
Evidence: `beak prepare` (run twice, the second says up to date), `beak migrate`, `beak doctor`, `flutter test`. Also one test that saves a book without a title and shows the rejection.
```

### An existing Flutter app

```text
Task: add a Beak admin panel for the Invoice table to this Flutter app without touching lib/main.dart.
Read first: .dart_tool/beak/docs/ai-index.md, then start-here/paths/existing-flutter-app.md and the Task map row "Add Beak to an existing Flutter app".
Run `beak init --dry-run` and show the plan before you run `beak init`.
Scope: pubspec.yaml, beak.yaml, .gitignore, and the new entrypoint lib/admin_main.dart. The app's own files stay as they are.
Evidence: `beak init` output, `beak doctor`, and the command that starts the panel (`flutter run -d chrome -t lib/admin_main.dart`). Show that `lib/main.dart` has no diff.
```

### An existing database

```text
Task: put an admin panel on the Postgres database in DATABASE_URL. Beak owns the schema from now on.
Use the beak-adopt-database skill. Before you wire anything, list every table and column introspect skipped and why, and every table whose primary key is an integer or whose column is a native Postgres enum.
Scope: lib/resources/, lib/migrations/, beak.yaml, .env.
Evidence: `beak introspect <url> --dry-run`, then `beak introspect <url>`, `beak prepare`, `beak doctor` and a `beak migrate` against an empty database that ends with the same tables. Do not run migrate against the source database.
```

### An existing Serverpod project

```text
Task: add a Beak admin for the Author and Book tables to this Serverpod 4 workspace. Serverpod owns the database, auth and migrations.
Use the beak-serverpod-setup skill. Read .dart_tool/beak/docs/serverpod/choosing-an-integration.md first and say which path you chose and why.
Do not start the server; tell me when to run `serverpod start`.
Scope: a new <name>_beak package, a new <name>_admin app, one gated endpoint and one deny-by-default policy in the server.
Evidence: `dart analyze` in the server, `flutter test` in the admin app, and a test that a signed-in user without the beak.admin scope is refused.
```

### An existing REST backend

```text
Task: show the /v1/customers endpoint of our REST backend in a Beak panel. The backend stays where it is.
Read first: .dart_tool/beak/docs/ai-index.md, start-here/paths/existing-backend.md, extending/model-transports.md.
Scope: a hand-written BeakModel for customers and its data source. No Beak server.
Evidence: `runBeakDataSourceContract` passes for the data source, and a widget test boots the panel against it. State which source methods the panel calls and which of them the backend does not support.
```

### An upgrade

```text
Task: move this project to Beak v0.10.0 and list every breaking change you applied.
Use the beak-upgrade skill. Read .dart_tool/beak/docs/start-here/upgrading.md and the changelog between the two versions.
Evidence: the `beak prepare` output before and after, `dart analyze`, `flutter test`, and `beak agents --check` exiting 0. Grep the project for each removed name listed in the changelog and show that nothing matches.
```

## Boundaries that work

A prompt with a stated result gets a small, checkable change. These are results from the shop example, each with the file that already implements it:

| State this result | Then point at |
| --- | --- |
| A dependent profile must belong to the selected customer | `examples/clean_beak_config/lib/resources/orders/models/order.dart` |
| A suggested price follows the product until the user overrides it | `examples/clean_beak_config/lib/resources/orders/models/order_item.dart` |
| Issuing an invoice freezes the historical amounts | `examples/clean_beak_config/lib/resources/invoices/models/invoice.dart` |
| The same sections appear as tabs on desktop and steps on a phone | `examples/clean_beak_config/lib/resources/invoices/screens/invoice_form.dart` |
| Adding variants stays local until Save | `examples/clean_beak_config/lib/resources/products/screens/variant_builder.dart` |

## Prompts per skill

The skills are workflows with a verification gate. Each already contains an example prompt; the prompts below are those, with the evidence to demand added. Use the skill name in the prompt so the agent loads it.

| Skill | Prompt |
| --- | --- |
| `beak-add-resource` | `Use the beak-add-resource skill to add a Supplier resource (name required, email, phone, active) that belongs to Company, with a searchable table, an active filter and a two-card form.` |
| `beak-evolve-schema` | `Use the beak-evolve-schema skill: products get a required unique sku (backfill existing rows from their id first) and the legacy_code column goes away.` |
| `beak-adopt-database` | `Use the beak-adopt-database skill on postgres://me@localhost:5432/shop with Beak owning the schema from now on. Show me every column it skipped and why before wiring resources.` |
| `beak-add-business-rule` | `Use the beak-add-business-rule skill: an invoice can only be issued with at least one line, and issuing freezes each line's price and tax rate.` |
| `beak-secure-api` | `Use the beak-secure-api skill: support staff read only their own company's orders and never see cost prices; admins see everything. Prove it with API tests for query, export and aggregate.` |
| `beak-upgrade` | `Use the beak-upgrade skill to move this project to Beak v0.10.0 and list every breaking change you applied.` |
| `beak-frontend-build-screens` | `Use the beak-frontend-build-screens skill: split the product form into Overview and Pricing tabs, edit variants in an inline table, and add a category filter to the product table.` |
| `beak-serverpod-setup` | `Use the beak-serverpod-setup skill to add a Beak admin to this Serverpod workspace for the Author and Book tables: staff read and write, nobody deletes, supplierCostInCents never leaves the server. Don't start the server; tell me when to run serverpod start.` |

Add one line to any of them: `Show me the output of every command the skill's Gate section lists.`

## Evidence to demand

| The change is | The agent must show |
| --- | --- |
| A new or changed schema class | `beak prepare` output with the files it wrote, the migration file, `beak migrate status`, `beak doctor` with no `WARN` for the table |
| A rule on a model | A test that saves the invalid value through the real API and gets a rejected receipt, and the same test failing before the rule |
| A screen or layout | A widget test that pumps the screen at a desktop and a phone width, and `flutter analyze` clean |
| Access control | One API test per role, each with the status it expects (`401`, `403`, `200`, or a smaller page for a row scope) |
| A migration | The file, `beak migrate --pretend` if the change is destructive, and `beak migrate status` after |
| A dependency or version change | `flutter pub get`, `beak agents --check` exiting `0`, `beak doctor` |
| Anything | `dart format .` with no diff and `flutter analyze` with no issues |

## Machine-readable twin

This page as Markdown: `https://simonerich.github.io/beak/ai/prompts/index.md`. In a project that ran `beak docs`: `.dart_tool/beak/docs/ai/prompts.md`. The skills themselves ship in `packages/beak/skills/`, `packages/beak_frontend/skills/` and `packages/beak_serverpod/skills/`, and `beak agents` copies them into the project.

## Continue reading

- [Task map](task-map.md): the rows the prompts above name.
- [Set up your agent](setup.md): install the skills these prompts call.
- [Rules for agents](rules.md): the rules the skeleton points at.
- [Choose your path](../start-here/paths/index.md): the five starting situations in full.
