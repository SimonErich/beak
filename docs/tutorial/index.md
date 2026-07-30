---
title: "Tutorial: First Flight"
description: Build a coffee-roastery admin panel from an empty folder to a deployed, authenticated store, one concept per chapter.
---

# Tutorial: First Flight

By the end of these six chapters you will have built
[`examples/store`](https://github.com/SimonErich/beak/tree/main/examples/store):
a working admin panel for a small coffee roastery, grown from an empty folder.
Seven resources declared once, a REST API generated from them, a panel that
lists, filters, edits and charts every one of them, accounts that decide who
sees what, and a test suite that proves it.

The bird has to leave the nest sometime. This is that flight, taken in short
hops.

Every code block is quoted from the finished example, so a snippet you copy is
code that compiles and ships. Nothing here is a toy version of the real thing.

## What you need

Dart 3.11 and Flutter stable. That is all: the database is a SQLite file Beak
creates on first run, and uploads land beside it. Postgres, S3 and Docker are
opt-in, and the last chapter shows where they plug in.

If you have not installed the CLI yet, start with
[Installation](../start-here/installation.md).

## The six chapters

| | Chapter | What you can do after it |
| --- | --- | --- |
| 1 | [Your first resource](01-your-first-resource.md) | Scaffold a project, declare a resource, and use the panel and API it produces |
| 2 | [Columns and validation](02-columns-and-validation.md) | Reach for the right column kind, and write rules that hold in the form and in the API |
| 3 | [Relationships](03-relationships.md) | Link resources by naming a class, and read what that gives you in the panel |
| 4 | [Seeding and the API](04-seeding-and-the-api.md) | Fill the store with fixed data, and drive every endpoint from the command line |
| 5 | [Shaping the panel](05-shaping-the-panel.md) | Decide icons, filters, actions, view modes, layouts, wizards, screens and the dashboard |
| 6 | [Auth, tests, and shipping](06-auth-tests-and-shipping.md) | Add accounts and a row policy, test the lot, and build for production |

Read them in order the first time. Each chapter starts where the last one
finished, and the project you end up with is the example you can clone.

## What you will not write

It is worth knowing in advance what the tutorial never asks you to type, so
you can notice its absence:

- No REST endpoints, request parsing, or response shaping.
- No table, form, detail page, filter bar, or router.
- No registry, no resource list, no migration list.
- No string column references, no `dynamic`, no casts.

You write schema classes, a handful of small files that state decisions, and
the code that is genuinely yours.

## If you would rather skim

- [Quickstart](../start-here/quickstart.md) is the same first chapter in a
  quarter of the words.
- [Cheatsheet](../reference/cheatsheet.md) is every command and annotation on
  one page.
- [`examples/store`](https://github.com/SimonErich/beak/tree/main/examples/store)
  is the finished project. Clone it and run it.

## Continue reading

- [Chapter 1: Your first resource](01-your-first-resource.md) starts the flight.
- [Core concepts](../concepts/index.md) is the same material as ideas rather
  than steps, if you prefer to read that way first.
