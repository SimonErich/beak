---
title: The obers_ui sibling caveat
description: Why obers_ui is a sibling path dependency, what breaks in a fresh clone or CI, and the two ways to satisfy it.
---

# The obers_ui sibling caveat

Beak's panel is built on obers_ui, and obers_ui is referenced by a relative path to a sibling checkout, not by a version on pub.dev. That one choice has a consequence worth understanding: a fresh clone will not resolve until obers_ui is present next to it. This page explains why, what breaks, and the two clean ways to fix it.

## Why a sibling path dependency

`beak_frontend` and the demo apps develop against obers_ui in lockstep. A path dependency means an edit in obers_ui shows up in Beak on the next hot reload, with no publish, no version bump, and no cache to clear. That is the right setup for two packages that grow together, and it mirrors the author's local layout under `~/Flutters`.

The declaration lives in `beak_frontend`, pointing three levels up so obers_ui sits beside the Beak repo root:

```yaml title="packages/beak_frontend/pubspec.yaml"
dependencies:
  obers_ui:
    path: ../../../obers_ui
  obers_ui_autoforms:
    path: ../../../obers_ui/packages/obers_ui_autoforms
  obers_ui_charts:
    path: ../../../obers_ui/packages/obers_ui_charts
```

From `packages/beak_frontend`, `../../../obers_ui` climbs past `packages/` and past the repo root to a sibling folder. On the author's machine that is `~/Flutters/obers_ui`, next to `~/Flutters/beak`.

## What breaks in a fresh clone

Clone Beak on its own and the first `pub get` fails: it cannot find `../../../obers_ui`, because nothing was ever checked out there. This bites in exactly two places.

- **A fresh clone on a new machine**, where you have Beak but not obers_ui beside it.
- **CI and container builds**, which start from a single-repo checkout with no sibling.

There are two ways to satisfy the dependency, and Beak uses both, each where it fits.

## Option A: check out obers_ui as a sibling (local dev)

For day-to-day development, clone obers_ui next to the Beak repo so the path resolves as written. obers_ui is a public repository.

```bash
cd ~/Flutters        # the folder that contains beak/
git clone https://github.com/SimonErich/obers_ui.git
# now ~/Flutters/beak and ~/Flutters/obers_ui are siblings
```

This is the setup the path dependency assumes, and it is the one you want for live editing across both packages.

## Option B: redirect obers_ui to git (standalone builds)

When there is no sibling to check out, point the dependency at its git source instead. Beak ships `deploy/web-overrides.yaml` for exactly this, and the web image copies it in as `pubspec_overrides.yaml` during the build.

```yaml title="deploy/web-overrides.yaml"
dependency_overrides:
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      ref: main
  obers_ui_autoforms:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_autoforms
      ref: main
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_charts
      ref: main
```

Two things make this work. First, `dependency_overrides` apply to the whole resolution, so the transitive path dependency declared inside `beak_frontend` is redirected here too, without editing `beak_frontend`. Second, pinning `ref` to a tag or commit instead of `main` makes the build reproducible. This is how the web image builds with no sibling checkout: see [Going to production](going-to-production.md).

## How CI handles it

CI does not use the git override. It takes the simpler road: check out both repositories, side by side, and let the path resolve exactly as it does on the author's machine. The workflow runs two checkout steps, placing Beak and obers_ui in sibling folders.

```yaml title=".github/workflows/ci.yaml"
- name: Checkout beak
  uses: actions/checkout@v4
  with:
    path: beak
- name: Checkout obers_ui (sibling path dependency)
  uses: actions/checkout@v4
  with:
    repository: ${{ vars.OBERS_UI_REPO || 'SimonErich/obers_ui' }}
    token: ${{ secrets.OBERS_UI_TOKEN || github.token }}
    path: obers_ui
```

A few notes on the knobs:

- The `path:` values put the two repos next to each other, so `../obers_ui` from the Beak root resolves just as `../../../obers_ui` does from a package.
- `OBERS_UI_REPO` is a repository variable you can override if obers_ui ever moves; it defaults to `SimonErich/obers_ui`.
- `OBERS_UI_TOKEN` covers a private mirror. For the public repo, the fallback `github.token` is enough.

After both checkouts, `melos bootstrap` resolves the workspace and the path dependency is satisfied. No override, no git fetch of obers_ui, no surprises.

!!! tip "Which option is which"
    Editing obers_ui alongside Beak: **Option A**, a sibling clone. Building a self-contained image or CI job with no sibling: **Option B**, the git override (or CI's two-repo checkout, which is the same idea done with two checkout steps).

## Continue reading

- [Going to production](going-to-production.md) how the web image applies the git override.
- [Installation](../start-here/installation.md) getting Beak and obers_ui side by side to start.
- [Project structure](../start-here/project-structure.md) where `beak_frontend` and the apps sit in the tree.
