---
title: 10. Wrap-up and where to fly next
description: A recap of the roastery admin you built and the concepts you met, with pointers into the concepts, reference, deployment, and extending sections.
---

# 10. Wrap-up and where to fly next

You have a working admin panel for a coffee roastery: six resources with full CRUD,
seeded data, filters and actions, a custom dashboard, a stepped product wizard,
bespoke order pages that double as edit forms, and a themed, guarded shell. It runs
against a generated Shelf backend you never hand-wrote an endpoint for. This chapter
takes stock and points you at where to read next. No new code.

## What you built

The store came together one concept at a time, and each concept is still there in
the app you can run:

- **A three-package layout** (chapter 1): shared models, a Shelf server on port 8080,
  and a Flutter panel, wired together with Melos and backed by Postgres and MinIO.
- **Your first model and migration** (chapter 2): `CategoryModel`, its typed column
  constants, and an explicit migration you registered and applied.
- **A live panel** (chapter 3): one `BeakResource` turned the model into a
  list/create/show/edit surface, with no per-page code.
- **Relationships and rich columns** (chapter 4): tags and the showcase
  `ProductModel`, with an enum badge, a euro-prefixed decimal, an image upload with a
  transform pipeline, a belongs-to category, and belongs-to-many tags.
- **Seeded data** (chapter 5): a repeatable seeder with fixed ids, then the factory
  toolkit for larger data sets.
- **Filters, actions, and view modes** (chapter 6): select and text filters on
  products, a `duplicateProduct` record action, and an alternate view of the list.
- **A dashboard** (chapter 7): config-only stats and a chart, then a custom
  `BeakScreen` at the root route built from blocks.
- **Better forms** (chapter 8): conditional sections, a product wizard, and one block
  layout serving both the order detail page and its edit form.
- **Polish** (chapter 9): auth, a live theme toggle, a notification bell, the command
  bar, and maintenance pages.

## The concepts you met

Behind the store are a handful of ideas that carry across the whole framework. You
have now seen each of them at work:

- **The one-definition promise.** A single typed `BeakColumn` fed the table cell, the
  form field, the detail row, the filter, the API validation, and the export column.
  You declared each field once.
- **The type-safety promise.** You addressed data through column constants, never a
  string key, and never touched `dynamic`.
- **The four layers.** The panel rendered state and forwarded intent; the backend
  mapped typed exceptions to HTTP. No plumbing in between.
- **The block system.** One sealed union of blocks composed your dashboard, your form
  layouts, and your detail pages, and the record blocks rendered values on one surface
  and inputs on another.
- **Source-agnostic data.** Everything ran over a `BeakDataSource`: HTTP in the panel,
  the worm ORM on the server, the same interface on both sides.

## Where to fly next

The roastery is a starting point. Pick a direction:

- **Understand the machinery.** [Core concepts](../concepts/index.md) explains the
  promises and layers you leaned on, in depth. Start with
  [The one-definition promise](../concepts/the-one-definition-promise.md) and
  [The block system](../concepts/the-block-system.md).
- **Look up an exact API.** The [Reference](../reference/index.md) is exhaustive:
  every [column type](../reference/column-types.md), every
  [configuration option](../reference/configuration-options.md), and the full
  [REST API](../reference/rest-api.md) the backend generates.
- **Ship it.** [Deployment](../deployment/index.md) covers environment and config,
  the dev infrastructure, and [Going to production](../deployment/going-to-production.md).
- **Make it yours.** [Extending Beak](../extending/index.md) shows how to add
  [custom columns](../extending/custom-columns.md),
  [custom screens](../extending/custom-screens-and-pages.md), and a
  [custom data source](../extending/custom-data-sources.md) for a backend that is not
  worm.

That is a whole admin panel off the ground from models and config. Wherever you take
Beak next, the shape stays the same: define it once, and let the framework wire the
rest.

## Continue reading

- [Core concepts](../concepts/index.md) the ideas behind everything you built.
- [Reference](../reference/index.md) the exhaustive lookup for every API.
- [Deployment](../deployment/index.md) taking the store to production.
- [Extending Beak](../extending/index.md) columns, blocks, screens, and data sources of your own.
