---
title: 'Tutorial: Nestwatch'
description: Build a bird-sighting field journal on SQLite and learn worm end to end.
---

Nestwatch is a small console app that keeps a field journal of bird sightings. You will build it from an empty folder to a working command-line tool, and every worm feature you meet solves a real problem the journal has.

## What you build

A `nestwatch` package with two models, `Bird` and `Sighting`. A bird has a nickname and a species. A sighting records one bird seen at a place and time, with a group count. The app persists everything to a local SQLite file and answers questions like "which species did I see most?" and "what turned up between two dates?".

You drive it with two command-line surfaces:

- A worm CLI wired to your database (`dart run nestwatch migrate`, `db:seed`) for schema and seed data.
- Small scripts under `bin/` that log entries and print reports.

## The finished tree

By the end, your project looks like this:

```text
nestwatch/
├── bin/
│   ├── nestwatch.dart        # your worm CLI (migrate, db:seed)
│   ├── log_bird.dart         # part 2
│   ├── log_sighting.dart     # part 3
│   ├── report.dart           # part 5
│   ├── safety_nets.dart      # part 6
│   └── with_logging.dart     # part 6
├── config/
│   └── worm_config.dart
├── lib/
│   ├── factories/
│   │   └── bird_factory.dart
│   ├── models/
│   │   ├── bird.dart
│   │   └── sighting.dart
│   ├── observers/
│   │   └── sighting_observer.dart
│   ├── ids.dart
│   └── nestwatch.dart        # bootNestwatch()
├── migrations/
│   ├── 20260702_094946_create_birds_table.dart
│   └── 20260702_095231_create_sightings_table.dart
├── seeds/
│   └── birds_seeder.dart
└── pubspec.yaml
```

## How the parts fit

The code is cumulative. Each part adds files or lines to what came before, then ends with a command you run and the exact output you should see.

1. [Hatching the project](./01-hatching-the-project.md) sets up the package, the SQLite adapter, and your own worm CLI.
2. [Your first model](./02-your-first-model.md) defines `Bird`, its migration, and saves your first row.
3. [Sightings and relations](./03-sightings-and-relations.md) adds `Sighting` and a `Bird`-to-`Sighting` relationship.
4. [Seeding a fake flock](./04-seeding-a-fake-flock.md) builds a factory and a seeder for reproducible data.
5. [Queries that sing](./05-queries-that-sing.md) filters, groups, paginates, and ranks.
6. [Safety nets and wrap-up](./06-safety-nets-and-wrap-up.md) adds validation, an observer, a transaction, and query logging, then points you at the rest of the docs.

## What you learn

By working through the six parts you meet worm's core surface in the order you would actually use it: defining a model over an attribute store, writing and running migrations, declaring and eager-loading a relationship, generating data with factories and seeders, building typed queries with filters and aggregates, and guarding writes with validation, observers, and transactions. Each concept arrives when the journal needs it, not as a feature checklist.

## Before you start

You need the Dart SDK 3.11 or newer. This tutorial was built and run on Dart 3.12. You do not need Postgres, Docker, or any server. Worm's SQLite driver writes to a plain file, so the whole app runs on your laptop with nothing else installed.

Every model in this tutorial is hand-written so you can see exactly what worm needs: an attribute store, a `tableName`, an `id`, a `toRow`, and a typed companion class. Worm can generate those companion classes for you, and each part links to the concept page that explains the generated path. For setup details and dependency options, see [Installation](../start-here/installation.md).

## Continue reading

- [Part 1: Hatching the project](./01-hatching-the-project.md)
- [Installation](../start-here/installation.md)
