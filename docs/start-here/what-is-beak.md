---
title: What is Beak?
description: What Beak is, where the name comes from, what it is for and what it is not, and the packages that make it up.
---

# What is Beak?

After this page you will be able to say in one sentence what Beak does, know
which package holds which piece, and recognize the one definition that the whole
framework reads from.

Beak is a low-code, configuration-driven admin-panel framework for Dart and
Flutter. You define a model once, its columns, validation, relationships, and
storage, and Beak composes obers_ui widgets that auto-wire to a Shelf backend.
No hand-written endpoints, no client/server plumbing, fully type-safe, zero
Material.

## The one-definition idea in a sentence

Most admin panels are the same code written three times: once for the database,
once for the API, and once for the UI, kept in sync by hand until they drift.
Beak asks you to write the field once, as a typed constant, and then reads that
one definition from every side. Change it in one place and the table, the form,
the validator, and the export all move together.

## Where the name comes from

Flutter's mascot is a bird (Dash). Birds have beaks, and a beak is the tool the
bird uses to get things done. Beak is the tool you reach for when your Flutter
app grows the dashboard or admin panel that almost every app grows eventually.

Its sibling is `worm`, the ORM that `beak_backend` runs on. The bird has to eat
something. You will meet worm only
in two places (migrations and seeders); everywhere else, Beak keeps the ORM
behind an interface so it never leaks into your models or your panel.

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
- **Config-over-code teams.** If you would rather describe a resource than wire
  one, and you want AI agents to generate correct panels from a schema, Beak's
  declarative surface is the point.

## What Beak is not for

Being honest about the edges saves you a wrong turn.

- **Not a public-facing app builder.** Beak's UI is obers_ui admin widgets:
  tables, forms, detail views, dashboards. It is not a toolkit for a consumer
  marketing site or a pixel-bespoke mobile app.
- **Not a headless CMS or a no-code SaaS.** Beak is a set of Dart/Flutter
  packages you compose in code. There is no hosted control panel; the panel is
  your Flutter app.
- **Not tied to one database forever.** `beak_backend` runs on worm today, but
  `BeakDataSource` is an interface. The seam is there so a different ORM (or a
  future `beak_serverpod`) can slot in without rewriting your models.

## The package family

Beak is a small monorepo. Each package owns one layer, and the layers speak the
shared vocabulary that lives in `beak_core`.

| Package | What it is |
| --- | --- |
| [`beak_core`](../reference/packages.md) | Pure Dart, no Flutter and no worm. Typed columns and rules, relationships, the serializable `BeakQuerySpec` wire contract, the storage abstraction with file rules, the `BeakDataSource` seam, and the raw `BeakClient` escape hatch. |
| [`beak_backend`](../reference/packages.md) | The Shelf server. Generated CRUD, query, batch, relations, and aggregate endpoints; validated uploads with image transforms; auth; global search; CSV export. All from a `BeakModelRegistry` over worm. |
| [`beak_frontend`](../reference/packages.md) | The Flutter panel. `BeakPanel` (shell plus router) and the generated tables, forms, detail views, actions, filters, and dashboards, built on obers_ui with HookWidget, Signals, GetIt, and go_router. |
| [`beak_cli`](../reference/cli-commands.md) | Scaffolding. `beak make:resource` and friends, and `beak doctor` to check your paths, `.env`, and Docker services. |
| `beak_storage_s3` / `beak_storage_ftp` | Pluggable storage drivers you register at startup. Memory and local disk ship inside `beak_core`. |
| `beak_image` | The image transform runner (the pixel codec) that powers thumbnail and format transforms on upload. |
| `examples/store*` | The store example: shared models, the server binary, the Flutter panel, and the end-to-end acceptance suite that drives all of it over real HTTP. |

The obers_ui trio (`obers_ui`, `obers_ui_autoforms`, `obers_ui_charts`) is
referenced by path and supplies every widget the panel renders. Beak never draws
a Material widget of its own.

## The one definition, in code

Here is the promise made concrete. A namespaced class of `const` column
definitions is the single source of truth for a resource's fields:

```dart title="README.md"
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name', label: 'Name',
    searchable: true, sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price', label: 'Price', prefix: '€', rules: [BeakMin(0)],
  );
  static const List<BeakColumn> values = [name, price];
}
```

That is not UI code, and it is not server code. It is a description both sides
read. From `ProductColumns.price` alone, the panel renders a currency cell in
the table and a numeric input in the form (with `BeakMin(0)` as a client
validator), while the server re-runs the same `BeakMin(0)` on every write and
adds a `Price` column to the CSV export. One declaration, six consumers, no
drift.

!!! note "Where this goes next"
    The real product model in the reference store carries ten columns, an enum
    badge, an image with upload rules, and two relationships. See
    [Defining models](../models/defining-models.md) for the full shape, and
    [The one-definition promise](../concepts/the-one-definition-promise.md) for
    the mechanism behind the six consumers.

## Continue reading

- [Why Beak?](why-beak.md) the argument for this approach and its tradeoffs.
- [The one-definition promise](../concepts/the-one-definition-promise.md) how one
  column feeds six surfaces.
- [Quickstart](quickstart.md) see the whole thing running in a few minutes.
- [Packages](../reference/packages.md) the full export list for every package.
