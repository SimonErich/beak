---
title: Guides
description: Task-focused recipes for testing, working with AI agents, performance, and security in a Beak project.
---

# Guides

The rest of the docs teach Beak one concept at a time. This section is the other
way in: short, task-shaped guides you reach for when you already know roughly
what you want and need the recipe. After this page you know which guide answers
which question.

## What is here

Each guide stands on its own. Read the one that matches the job in front of you.

| Guide | Read it when you want to |
| --- | --- |
| [Testing](testing.md) | Prove a resource works without a live server: render the panel against `InMemoryBeakDataSource`, count a screen's round-trips with `BeakRecordingDataSource`, and boot your real API on `sqlite::memory:`. |
| [Working with AI agents](working-with-ai-agents.md) | Point a coding agent at the `AGENTS.md` `beak create` wrote, have it add a resource as one annotated class, and rely on the analyzer and `beak doctor` to catch what it gets wrong. |
| [Performance](performance.md) | Keep pages fast: a list page and a show page each cost one query with their relations, aggregates run in the database, and relation managers page their rows. |
| [Security](security.md) | Close the seams in `lib/server.dart`: the auth guard, the policy, a row scope that narrows which rows a principal sees, upload validation, and CORS. |
| [Recipes](../recipes/index.md) | Grab a copy-paste answer to a recurring task (a row action, a KPI, a kanban board, a picker, a CSV export) without reading a whole concept page. One page per recipe. |

## How the guides relate to the rest of the docs

A guide is a shortcut, not a replacement. Where a guide leans on a concept, it
links to the page that explains it. Testing points at
[Results and errors](../concepts/results-and-errors.md) for the exception family
it asserts on. Working with AI agents points at
[Defining a resource](../models/defining-models.md) for the one class an agent
writes. Follow the link when you want the why behind the recipe.

The canonical application is [`examples/clean_beak_config`](https://github.com/SimonErich/beak/tree/main/examples/clean_beak_config).
Framework-specific guides also cite focused package implementations and tests.

## Continue reading

- [Testing](testing.md) the test seams every Beak package is built on.
- [Working with AI agents](working-with-ai-agents.md) why config-over-code is a
  good fit for a coding agent.
- [Performance](performance.md) how many queries each surface costs, and why.
- [Security](security.md) the auth, policy, row-scope, and upload guards worth
  knowing before you ship.
