---
title: Start here
description: Where to begin with Beak: pick the path that fits, from a five-minute quickstart to the full tutorial.
---

# Start here

Welcome. Beak is a low-code, configuration-driven admin-panel framework for
Dart and Flutter: you define a model once and get a whole dashboard. This page
points you at the right starting place depending on what you came to do.

You do not have to read this section in order. If you already know you want to
build something, skip to the quickstart. If you want to understand the shape of
the thing first, start with the two conceptual pages below.

## Pick your path

=== "I want to see it work"

    Run the reference admin against a real server on your machine, then read the
    code that made it. About five minutes of copy-paste.

    - [Installation](installation.md) gets the toolchain, Docker services, and
      `.env` in place.
    - [Quickstart](quickstart.md) boots the reference admin: migrate, seed,
      serve on port 8080, and open the Flutter panel.

=== "I want to learn it properly"

    Build a small coffee-roastery admin from an empty folder, one concept at a
    time. This is the long way, and the way that sticks.

    - [Tutorial: First Flight](../tutorial/index.md) is ten chapters from
      `flutter create` to a themed, authenticated panel.

=== "I want to understand it first"

    Read the mental model before touching a keyboard. Two short pages carry most
    of Beak's design.

    - [What is Beak?](what-is-beak.md) what it is, what it is for, and the
      package family.
    - [Why Beak?](why-beak.md) the argument for config over code, and the honest
      tradeoffs.
    - [Core concepts](../concepts/index.md) the seven ideas that make Beak tick.

=== "I need a specific answer"

    You have used Beak before and you want a signature, a route, or a flag.

    - [Cheatsheet](../reference/cheatsheet.md) the one-page recall card.
    - [Reference](../reference/index.md) exhaustive tables for every public
      symbol.

## Everything in this section

| Page | What it gives you |
| --- | --- |
| [What is Beak?](what-is-beak.md) | The elevator pitch, the name story, the package family table, and what Beak is (and is not) for. |
| [Why Beak?](why-beak.md) | The case for configuration over hand-written code, and where that case stops. |
| [Installation](installation.md) | Toolchain versions, Docker services, and the `.env` file the demos expect. |
| [Quickstart](quickstart.md) | The reference admin running end to end: server on port 8080, panel in Chrome. |
| [Project structure](project-structure.md) | How the monorepo is laid out and which folder does what. |

!!! tip "Two demo apps, two ports"
    Beak ships two example apps. The **reference admin**
    (`apps/reference_admin*`) is the small teaching store this section and the
    tutorial use; its server runs on port 8080. The **superdashboard**
    (`apps/beak_superdashboard`) is the kitchen-sink showcase the feature pages
    use; its server runs on port 8180. When you copy a snippet, match its
    `apiBaseUrl` port to the app it came from.

## Continue reading

- [What is Beak?](what-is-beak.md) the one-paragraph answer, then the details.
- [Quickstart](quickstart.md) the fastest route to a running panel.
- [Tutorial: First Flight](../tutorial/index.md) build the coffee roastery from
  scratch.
