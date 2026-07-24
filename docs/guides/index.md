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
| [Testing](testing.md) | Prove a resource works without a live server: inject a fake data source into the panel, drive the API over an in-memory database, and pin the query wire format with a golden test. |
| [Working with AI agents](working-with-ai-agents.md) | Hand model and resource definitions to a coding agent, scaffold with the CLI, and rely on Beak's type system to catch anything the agent gets wrong. |
| [Performance](performance.md) | Keep list pages fast: eager-load relations instead of paying the N+1 tax, page your queries, and read the query counts the tests assert. |
| [Security](security.md) | Understand the auth surface, the per-operation policy gate, and how storage keys and upload rules are validated on both sides. |
| [Common recipes](common-recipes.md) | Grab a copy-paste answer to a recurring task (a custom action, a computed column, a filtered relation load) without reading a whole concept page. |

## How the guides relate to the rest of the docs

A guide is a shortcut, not a replacement. Where a guide leans on a concept, it
links to the page that explains it. Testing points at
[Results and errors](../concepts/results-and-errors.md) for the exception family
it asserts on. Working with AI agents points at
[Defining models](../models/defining-models.md) for the one definition an agent
writes. Follow the link when you want the why behind the recipe.

## Continue reading

- [Testing](testing.md) the test seams every Beak package is built on.
- [Working with AI agents](working-with-ai-agents.md) why config-over-code is a
  good fit for a coding agent.
- [Security](security.md) the auth, policy, and upload guards worth knowing before
  you ship.
