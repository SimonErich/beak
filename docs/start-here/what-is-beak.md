---
title: What is Beak?
description: What Beak is, where the name comes from, what it is for and what it is not, and the one dependency and eight libraries it ships as.
---

# What is Beak?

After this page you will be able to say in one sentence what Beak does, know
which library holds which piece, and recognize the one declaration the whole
framework reads from.

Beak is a low-code, configuration-driven admin-panel framework for Dart and
Flutter. You declare a resource once, as an annotated Dart class, and Beak
generates the REST API, the migration, and a panel of obers_ui widgets over it.
No hand-written endpoints, no client/server plumbing, fully type-safe, zero
Material.

## The one-definition idea in a sentence

Most admin panels are the same code written three times: once for the database,
once for the API, and once for the UI, kept in sync by hand until they drift.
Beak asks you to declare the field once, as a typed Dart field, and then reads
that one declaration from every side. Change it in one place and the table, the
form, the validator, the migration, and the export all move together.

## The one definition, in code

Here is the promise made concrete. This is a whole resource, and the file is
complete:

```dart title="examples/store/lib/models/category.dart"
--8<-- "examples/store/lib/models/category.dart"
```

The field's **type** picks the column kind. `String` is a single-line text
column, `BeakText` a multi-line one, `double` a decimal, `DateTime` a date and
time, `BeakImageRef` an upload. Its **nullability** decides required-ness, once, for
the form validator, the API's validation and the database's `NOT NULL` alike.
`@Column` carries only what a Dart type cannot say: the label, the rules, which
surfaces show the field.

Then you run:

```bash
beak prepare
```

Beak writes `category.beak.dart` beside the class: the typed column constants
(`CategoryColumns.name`), the relationship constants on both sides
(`CategoryRelations.products`, from the `@BelongsTo` on `Product`), the
`CategoryModel` that the server and the panel both read, and a typed
`CategoryRecord`. It also writes the migration this table
needs and the wiring that registers all of it. There is no registry to edit and
no resource to declare: a file under `lib/models/` is a resource.

That generated model is not UI code, and it is not server code. It is a
description both sides read. From `ProductColumns.price` alone, the panel
renders a currency cell in the table and a numeric input in the form (with
`BeakMin(0)` as a client validator), while the server re-runs the same
`BeakMin(0)` on every write and adds a `Price` column to the CSV export. One
declaration, six consumers, no drift.

!!! note "Where this goes next"
    The product model in the store example carries every column kind Beak has,
    all four relationship kinds, soft deletes and timestamps, in one class. See
    [Defining a resource](../models/defining-models.md) for the full shape,
    [Generated code](../models/generated-code.md) for what lands in the part
    file, and
    [The one-definition promise](../concepts/the-one-definition-promise.md) for
    the mechanism behind the six consumers.

## Where the name comes from

Flutter's mascot is a bird (Dash). Birds have beaks, and a beak is the tool the
bird uses to get things done. Beak is the tool you reach for when your Flutter
app grows the dashboard or admin panel that almost every app grows eventually.

Its sibling is `worm`, the ORM Beak's server half runs on. The bird has to eat
something. You will meet worm in two places only, migrations and seeders;
everywhere else Beak keeps the ORM behind an interface so it never leaks into
your models or your panel.

## What Beak is for

Beak is built for the internal-facing surface of an app: the place your team,
your admins, or your operators go to manage the data the public app produces.

- **The admin panel every app grows.** Products and orders, users and roles,
  content and moderation queues. The CRUD-heavy back office that is unglamorous
  to build by hand and easy to build inconsistently.
- **The dashboard that is the whole product.** Sometimes the internal tool *is*
  the product: an ops console, a data-review workbench, a B2B admin you ship to
  customers. Beak scales up to that with custom screens, dashboards, and a full
  block system.
- **A panel bolted onto an app that already exists.** `BeakServer.handler`
  mounts inside a Shelf pipeline you already run, and a `BeakBlockHost` renders
  inside a screen that is not a panel. See `examples/embedded`.
- **Config-over-code teams.** If you would rather describe a resource than wire
  one, and you want AI agents to generate correct panels from a schema, Beak's
  declarative surface is the point.

## What Beak is not for

Being honest about the edges saves you a wrong turn.

- **Not a public-facing app builder.** Beak's UI is obers_ui admin widgets:
  tables, forms, detail views, dashboards. It is not a toolkit for a consumer
  marketing site or a pixel-bespoke mobile app.
- **Not a headless CMS or a no-code SaaS.** Beak is a Dart/Flutter package you
  add to a project you own. There is no hosted control panel; the panel is your
  Flutter app.
- **Not tied to one database forever.** Beak's server half runs on worm today,
  but `BeakDataSource` is an interface. The seam is there so a different ORM
  (or a future `beak_serverpod`) can slot in without rewriting your models.

## One dependency, eight libraries

Your pubspec names Beak once:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      path: packages/beak
```

Behind that one name are eight libraries. Which one a file imports says what
that file is: a model, a screen, a server, a migration, a test.

| Import | What it holds |
| --- | --- |
| `package:beak/beak.dart` | Columns, models, relationships, the serializable `BeakQuerySpec`, the `BeakDataSource` seam, the storage abstraction, and the raw `BeakClient`. No Flutter, no `dart:io`. |
| `package:beak/schema.dart` | The annotations a schema class carries: `@Resource`, `@Column`, `@Display`, `@BelongsTo` and the rest. |
| `package:beak/panel.dart` | The panel: `BeakPanel`, resources, blocks, tables, forms, detail views, actions, dashboards. |
| `package:beak/server.dart` | The Shelf host: config, storage wiring, auth, policies. |
| `package:beak/migrations.dart` | The schema DSL for migrations and seeders. |
| `package:beak/testing.dart` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, record factories, and the executable data-source contract. |
| `package:beak/ui.dart` | obers_ui, for a screen that draws its own widgets. |
| `package:beak/charts.dart` | obers_ui_charts. |

The split is enforced rather than trusted, because `bin/serve.dart` reaches
your models through the generated registry and a stray `dart:ui` import there
would stop the server compiling ahead of time.
[Libraries](../reference/libraries.md) has the long version.

Underneath, Beak is a small monorepo of layered packages: `beak_core` (the
shared vocabulary), `beak_backend` (the Shelf server), `beak_frontend` (the
panel), `beak_cli` (the `beak` command), the S3 and FTP storage drivers,
`beak_image`, and the vendored worm ORM. You never depend on them individually.
[Packages](../reference/packages.md) describes them for contributors and for
anyone reading the source.

The obers_ui trio (`obers_ui`, `obers_ui_autoforms`, `obers_ui_charts`) comes
in with the `beak` package and supplies every widget the panel renders. Beak
never draws a Material widget of its own.

## The examples

Four projects in the repository, each answering a different question.

| Example | What it is |
| --- | --- |
| `examples/quickstart` | Exactly what `beak create` produces, checked in. |
| `examples/store` | The teaching example this section and the tutorial quote: every column kind, all four relationship kinds, auth with a row policy, uploads, a wizard, a dashboard. API on port 8080. |
| `examples/superdashboard` | The same ideas at 49 models: 17 navigable resources, every one of the 48 block types, charts, maps. API on port 8180. |
| `examples/embedded` | Beak mounted inside an application that already exists, including a table another system owns. |

## Continue reading

- [Why Beak?](why-beak.md) the argument for this approach and its tradeoffs.
- [The one-definition promise](../concepts/the-one-definition-promise.md) how one
  declaration feeds six surfaces.
- [Quickstart](quickstart.md) see the whole thing running in a few minutes.
- [Annotations](../reference/annotations.md) every annotation a schema class can
  carry.
