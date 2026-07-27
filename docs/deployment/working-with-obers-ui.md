---
title: Working with obers_ui
description: How Beak pins obers_ui by git commit so a fresh clone resolves, and how to develop against a local obers_ui checkout when you need to.
---

# Working with obers_ui

Beak's panel is built on obers_ui, which is not published on pub.dev. Beak
depends on it by **pinned git commit**, so cloning Beak on its own is enough:
`melos bootstrap` fetches obers_ui into the pub cache and the workspace
resolves. Nothing has to be checked out beside the repo.

This page explains the pin and the one case where you want to override it.

!!! note "This used to be a caveat"
    Earlier versions of Beak declared obers_ui as a path dependency climbing
    above the repo root (`../../../obers_ui`). That made a fresh clone fail to
    resolve, forced CI to check out two repositories, and required a
    build-time override file for container images. All of that is gone; if you
    are following an older guide that mentions a sibling checkout or
    `deploy/web-overrides.yaml`, it is out of date.

## The pin

The dependency is declared in `beak_frontend` and, for `OiIcons`, in the two
demo apps:

```yaml title="packages/beak_frontend/pubspec.yaml"
dependencies:
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
  obers_ui_autoforms:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_autoforms
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_charts
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
```

Three details worth knowing:

- **`ref` is a full 40-character commit SHA, not a branch.** A branch name
  would make every build a different build. `obers_ui_autoforms` and
  `obers_ui_charts` live inside the same repository, addressed with `path:`.
- **The three packages must agree.** They path-depend on each other inside the
  checkout, so a mismatched ref would resolve two copies of `obers_ui`.
  `test/obers_ui_pin_test.dart` fails the build if the SHAs ever diverge, or if
  anyone reintroduces a path dependency that escapes the repo.
- **This is a pre-1.0 arrangement.** Once obers_ui publishes to pub.dev these
  become ordinary version constraints, and the pin disappears.

## Bumping obers_ui

Update the `ref` in all three places — `packages/beak_frontend`,
`examples/store`, and `apps/superdashboard` — then re-bootstrap:

```bash
melos bootstrap
melos run analyze && melos run test
```

The pin test will tell you immediately if you missed a copy.

## Developing against a local obers_ui checkout

When you are changing obers_ui and Beak together, a pinned commit is exactly
the wrong thing: you want your working copy, hot-reloadable. Clone obers_ui
beside the Beak repo and link it:

```bash
cd ..                                                    # next to beak/
git clone https://github.com/SimonErich/obers_ui.git
cd beak
melos run link-obers-ui
```

That writes path `dependency_overrides` into the `pubspec_overrides.yaml` of
the three packages that depend on obers_ui, and re-bootstraps. Melos manages
only the entries listed in each file's
`# melos_managed_dependency_overrides:` header, so these survive later
bootstraps. When you are done:

```bash
melos run link-obers-ui -- --unlink
```

Both files are git-ignored, so a link never leaks into a commit.

!!! tip "Why not melos's dependencyOverridePaths"
    Melos can do this itself, but it applies the overrides to *every* package
    in the workspace — including the pure-Dart ones. That drags the Flutter SDK
    into `beak_core`, `beak_cli`, `beak_image` and the storage drivers, and
    makes `dart pub get` there require Flutter. `link-obers-ui` touches only
    the packages that actually depend on obers_ui.

## Continue reading

- [Going to production](going-to-production.md) the container images, which now
  need no dependency overrides at all.
- [Installation](../start-here/installation.md) getting a Beak workspace
  resolved.
- [Project structure](../start-here/project-structure.md) where `beak_frontend`
  and the apps sit in the tree.
