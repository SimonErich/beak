---
title: Choose your path
description: Six starting situations for Beak, from an empty folder to an existing database, Flutter app, Serverpod project or backend, each with the pages to read first.
type: index
audience: [beginner, expert, agent]
status: stable
---

# Choose your path

Most people arrive at Beak with something already in hand: a database, an app, a Serverpod project, a backend, or nothing at all. This section has one page per situation, with the exact commands, the decisions that matter and what does not work yet. Pick the row that matches yours.

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Start from nothing and decide the database, the entrypoint and when to add sign-in | [A new project](new-project.md) | `beak create`, SQLite or Postgres, generated or authored, auth later |
| Put a panel over tables you already have | [An existing database](existing-database.md) | `beak introspect` with `adopt` or `external` ownership, and the limits of legacy schemas |
| Add an admin to a Flutter app that has its own `main.dart` | [An existing Flutter app](existing-flutter-app.md) | `beak init`, the second entrypoint, mounting in your router, sharing the session |
| Add an admin to a Serverpod 4 project | [An existing Serverpod project](existing-serverpod-project.md) | Five questions that pick the admin app or the client bridge |
| Keep a REST or RPC backend you cannot move | [An existing backend](existing-backend.md) | Model-owned transports, a `BeakDataSource`, error mapping and the contract suite |
| Change Beak itself | [Contributing to Beak](contributing.md) | Clone, Melos, the four-command gate and the obers_ui pin |

## What to read after the path page

Each situation has three pages worth reading next, in this order.

| If you started with | Then | Then | Then |
| --- | --- | --- | --- |
| A new project | [Quickstart](../quickstart.md) | [Project structure](../project-structure.md) | [Tutorial](../../tutorial/index.md) |
| An existing database | [Migrations](../../backend/migrations.md) | [Defining models](../../models/defining-models.md) | [Security](../../shipping/security.md) |
| An existing Flutter app | [Using Beak widgets standalone](../../extending/using-beak-widgets-standalone.md) | [Auth and idle-lock](../../panel/auth-and-idle-lock.md) | [Running the server](../../backend/running-the-server.md) |
| An existing Serverpod project | [Choosing an integration](../../serverpod/choosing-an-integration.md) | [Setting up the admin app](../../serverpod/admin-app/setup.md) or [Client bridge](../../serverpod/bridge/index.md) | [Authentication and scopes](../../serverpod/authentication.md) |
| An existing backend | [Model-owned transports](../../extending/model-transports.md) | [Custom data sources](../../extending/custom-data-sources.md) | [Testing](../../shipping/testing.md) |
| Contributing | [Contributing](../../contributing/index.md) | [Code guardrails](../../contributing/code-guardrails.md) | [Architecture](../../architecture/index.md) |

Two things apply to every path today. A default `beak create` or `beak init` pins `ref: v0.9.0`, which does not exist until the release is tagged, and the panel needs a working obers_ui checkout until the pinned commit catches up. Both are on [Installation](../installation.md), with the workaround.

Coming from an older Beak checkout is not a path of its own. Read [Upgrading](../upgrading.md).

## Continue reading

- [A new project](new-project.md): the shortest way to a running panel.
- [An existing database](existing-database.md): the path with the most sharp edges, documented as they are.
- [Two ways to boot a panel](../generated-or-authored.md): the choice every path eventually makes.
