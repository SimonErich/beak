---
title: Quickstart
description: Create a Beak project, migrate its SQLite database, serve the API and open the panel, using the generated bootstrap.
type: tutorial
audience: [beginner]
status: stable
---

# Quickstart

In about ten minutes you go from an empty folder to a running admin panel: a table, a create form, a detail page and a REST API for one model, plus the two commands you use when you change it.

This page uses the generated bootstrap, where `beak.yaml` and `beak prepare` build the panel for you. [Two ways to boot a panel](generated-or-authored.md) explains the other one and when to switch.

## What you'll build

A project called `acme_admin` with one `Note` model. At the end you have:

- a SQLite database created by a migration you can read,
- a REST API on `http://localhost:8080`,
- a panel in Chrome that lists, creates, edits and deletes notes,
- a second resource (`Product`) and a new column on `Note`, both added the way you will add the next hundred.

You write one small Dart class per model. Everything else in the list above comes from it.

## Before you start

| You need | Why |
| --- | --- |
| The `beak` command | [Installation](installation.md) has the two lines. `beak --version` prints `beak 0.9.0`. |
| Dart `^3.11`, Flutter `3.41` or newer | The API runs on Dart, the panel on Flutter. |
| Chrome | Runs the panel. Any Flutter web device works. |
| A free port `8080` | The API listens there. `PORT=9090 beak dev` moves it. |

No Docker and no database server. A new project uses a SQLite file.

!!! warning "Pre-release"
    Until `v0.9.0` is tagged you create the project with `--beak-path`, and until the obers_ui pin moves the panel needs a `pubspec_overrides.yaml`. Both are on [Installation](installation.md#the-release-is-not-tagged-yet). The commands below assume you did that; the API steps work without the override.

## Run it

### 1. Create the project

```bash
beak create acme_admin --beak-path "$PWD/beak"
cd acme_admin
```

`$PWD/beak` is the clone from the installation page. Once the tag exists, the flag goes away and it is `beak create acme_admin`.

```console
$ beak create acme_admin --beak-path "$PWD/beak"
  created acme_admin/pubspec.yaml
  created acme_admin/beak.yaml
  created acme_admin/lib/resources/notes/models/note.dart
  created acme_admin/lib/main.dart
  created acme_admin/.gitignore
  ...
Resolving dependencies...
Changed 142 dependencies!
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  8 of 9 files
  agents     AGENTS.md updated · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md

  next:
    cd acme_admin
    beak migrate
    beak dev
```

The `generated` line is the files `beak prepare` wrote out of the files it considered, the schema part and the wiring. It skips a file that would not change, so the first number moves between runs (`8 of 9` here, `up to date (8 files)` later). Read it as "done", not as an inventory.

The one model in the project is the `Note` schema class. It is the file you will edit most:

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
--8<-- "examples/quickstart/lib/resources/notes/models/note.dart"
```

### 2. Create the tables

```bash
beak migrate
```

```console
$ beak migrate
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_161500_create_notes_table
```

Two of the three are Beak's own tables (save receipts and the outbox). The third is yours: `lib/migrations/create_notes_table.dart`, written by `beak prepare` from the `Note` class. The database is `beak.db` beside `pubspec.yaml`. Beak never alters a database on its own, which is why this step exists at all.

### 3. Serve the API

```bash
beak dev
```

```console
$ beak dev
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
warning: Beak is listening on 0.0.0.0:8080 with BeakAllowAllPolicy, so every route answers every caller and CORS admits any origin. Pass a BeakPolicy to defaults.build(policy: ...), or set HOST=127.0.0.1 to keep it on this machine.
listening on http://0.0.0.0:8080
```

`beak dev` regenerates the wiring, serves the API and prints the line that starts the panel. It does not start Flutter for you, so the panel gets a second terminal. Leave this one running.

The `warning` line is expected on a new project: nothing restricts the API yet, which is what you want on your own machine and not what you want on a network. `HOST=127.0.0.1 beak dev` silences it; [Security](../shipping/security.md) covers the real fix.

### 4. Open the panel

In a second terminal, in the project:

```bash
flutter run -d chrome
```

Chrome opens on the panel. The sidebar has a `Content` section with `Notes`, the list has the columns `Title`, `Pinned` and `Updated`, a `Pinned` filter chip sits above the table, and `Create` is top right. Each row carries view, edit and delete actions. Click `Create`, add a note, save, and it appears in the list.

Ask the API for the same row:

```console
$ curl -s -X POST localhost:8080/api/notes/query -H 'content-type: application/json' -d '{"table":"notes"}'
{"items":[{"values":{"id":"7935615a-88d7-4c01-b1c4-2f28b8c455d8","title":"First note","body":null,"pinned":true,"created_at":{"type":"dateTime","value":"2026-09-29T14:17:32.354Z"},"updated_at":{"type":"dateTime","value":"2026-09-29T14:17:32.354Z"}},"relations":{}}],"total":1,"page":1,"perPage":25}
```

!!! note "What just happened"
    - `beak create` wrote the files you own, asked Flutter for `web/`, resolved packages and ran `beak prepare` once.
    - `beak prepare` read the `Note` class and generated the typed field references, the model, the migration, the API wiring and the panel configuration.
    - `beak migrate` ran the migrations. `beak dev` served the API the panel calls.
    - The panel is one `BeakApp` widget built from `lib/beak/panel.g.dart`. Nothing in it is hand-written.

!!! question "What this skipped"
    - Which of these files you may edit: [Project structure](project-structure.md).
    - Why there is no route or handler to write: [The one-definition promise](../concepts/the-one-definition-promise.md).
    - Where the panel gets its data: [How data flows](../concepts/how-data-flows.md).

## Add a field

Add `priority` to `Note`, right under `pinned`:

```dart title="lib/resources/notes/models/note.dart"
  /// How urgent the note is, 1 to 5.
  @Column(sortable: true, rules: [BeakMin(1), BeakMax(5)])
  late final int? priority;
```

`int?` makes it optional, the two rules bound it, and the form, the API and the database column all read that from the line above. Regenerate, then ask the doctor what changed:

```console
$ beak prepare
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  1 of 8 files
$ beak doctor
  ...
  WARN notes.priority is declared by Note.priority but missing from the database
       → beak make:migration AddPriorityToNotes --from-drift, then beak migrate
```

A new column needs a migration, and Beak drafts it from the difference between your classes and the live database:

```console
$ beak make:migration AddPriorityToNotes --from-drift
  created lib/migrations/add_priority_to_notes.dart
  run `beak migrate` to apply it
$ beak migrate
migrated  20260929_163545_add_priority_to_notes
```

The migration name is UpperCamelCase (`add_priority_to_notes` is rejected), and the generated file is yours from then on: read it before you apply it.

The running processes do not notice any of this. `beak dev` serves the registry it started with, and the panel keeps the configuration it was built with, so restart `beak dev` (Ctrl-C, run it again) and press `R` in the `flutter run` terminal for a hot restart. Hot reload (`r`) is not enough. Afterwards `Priority` is a column in the table and an input in the form.

## Add a resource

```console
$ beak make:resource Product --fields name:string!,price:decimal!
  created lib/resources/products/models/product.dart
  created lib/resources/products/product_resource.dart
$ beak migrate
migrated  20260929_163353_create_products_table
```

`make:resource` writes the schema class and a `ProductResource`, runs `beak prepare` and creates the migration. Restart `beak dev` and hot restart the panel, and `Products` joins the sidebar. The `ProductResource` class replaces the default resource of its model, so every option you set on it (icon, navigation group, screens) shows up in the sidebar and pages. `price:decimal!` produces an exact `BeakDecimal` field (`double` is a separate kind for a measurement). To give it a currency, add `BeakSemantic.money`; [A money field](../recipes/a-money-field.md) shows how.

## Checkpoint

Check each line before you move on.

| You should see | If not |
| --- | --- |
| `beak doctor` ends with `All checks passed.` | Read the `WARN` and `FAIL` lines; each one names the fix. |
| `beak migrate status` lists every migration as `applied`. | Run `beak migrate`. |
| The panel lists `Notes` and `Products` in the sidebar. | Run `beak prepare`, restart `beak dev`, then hot restart the panel (`R` in the `flutter run` terminal). |
| The list shows an error card with `Retry` instead of rows. | The panel cannot reach the API at `api.baseUrl` in `beak.yaml`. Start `beak dev`, or point `--dart-define=BEAK_API_BASE_URL=http://localhost:9090` at the port you chose. |
| `flutter run` fails inside `beak_frontend` with `No named parameter`. | The obers_ui pin is behind the code. Add the `pubspec_overrides.yaml` from [Installation](installation.md#link-obers_ui-until-the-pin-moves). |

## Continue reading

- [Project structure](project-structure.md): which of these files are yours and which Beak rewrites.
- [Tutorial](../tutorial/index.md): the same ideas, chapter by chapter, growing a shop.
- [Choose your path](paths/index.md): start from a database, an app or a backend you already have.
- [Two ways to boot a panel](generated-or-authored.md): the generated `BeakApp` and the authored `BeakPanel`.
