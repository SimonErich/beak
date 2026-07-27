---
title: Start here
description: Where to begin with Beak. Pick the path that fits, from a one-minute quickstart to the full tutorial.
---

# Start here

Welcome. Beak is a low-code, configuration-driven admin-panel framework for
Dart and Flutter: you declare a resource as one annotated class, run
`beak prepare`, and get a REST API and a Flutter panel over it. This page points
you at the right starting place depending on what you came to do.

You do not have to read this section in order. If you already know you want to
build something, skip to the quickstart. If you want to understand the shape of
the thing first, start with the two conceptual pages below.

## Pick your path

=== "I want to see it work"

    Create a project, declare one class, and open the panel it generates.
    About a minute of copy-paste, with no database to install.

    - [Installation](installation.md) puts the `beak` command on your path and
      scaffolds a project.
    - [Quickstart](quickstart.md) declares a resource, generates its wiring,
      creates the table, and serves the API on port 8080.

=== "I want to learn it properly"

    Build a small coffee-roastery admin from an empty folder, one concept at a
    time. This is the long way, and the way that sticks.

    - [Tutorial: First Flight](../tutorial/index.md) grows the store example
      from `beak create` to a themed, authenticated panel.

=== "I want to understand it first"

    Read the mental model before touching a keyboard. Two short pages carry most
    of Beak's design.

    - [What is Beak?](what-is-beak.md) what it is, what it is for, and the one
      dependency it ships as.
    - [Why Beak?](why-beak.md) the argument for one declaration over three
      hand-written layers, and the honest tradeoffs.
    - [Core concepts](../concepts/index.md) the seven ideas that make Beak tick.

=== "I need a specific answer"

    You have used Beak before and you want a signature, a route, or a flag.

    - [Cheatsheet](../reference/cheatsheet.md) the one-page recall card.
    - [Annotations](../reference/annotations.md) every annotation a schema class
      can carry.
    - [Reference](../reference/index.md) exhaustive tables for every public
      symbol.

## Everything in this section

| Page | What it gives you |
| --- | --- |
| [What is Beak?](what-is-beak.md) | The elevator pitch, the name story, the eight libraries, and what Beak is (and is not) for. |
| [Why Beak?](why-beak.md) | The case for one declaration over three hand-written layers, and where that case stops. |
| [Installation](installation.md) | The toolchain, the `beak` command, and the project it creates. |
| [Quickstart](quickstart.md) | Your own resource running end to end: API on port 8080, panel in Chrome. |
| [Project structure](project-structure.md) | What every folder is for, which files Beak generates, and which ones you can take over. |

!!! tip "Nothing to install but Dart and Flutter"
    A new project's database is a SQLite file created on first run. There is no
    Docker to start and no `.env` to fill in. Set `DATABASE_URL` when you want
    Postgres instead, which is a change you make later and on purpose. See
    [A real database](installation.md#a-real-database).

!!! note "Four examples ship with Beak"
    `examples/quickstart` is exactly what `beak create` produces.
    `examples/store` is the teaching example this section and the tutorial
    quote: every column kind, all four relationship kinds, auth with a row
    policy, uploads, a wizard and a dashboard, with its API on port 8080.
    `examples/superdashboard` is the same ideas at 49 models, on port 8180.
    `examples/embedded` mounts Beak inside an app that already exists. When you
    copy a snippet, match its `baseUrl` port to the example it came from.

## Continue reading

- [What is Beak?](what-is-beak.md) the one-paragraph answer, then the details.
- [Quickstart](quickstart.md) the fastest route to a running panel.
- [Tutorial: First Flight](../tutorial/index.md) build the coffee roastery from
  scratch.
