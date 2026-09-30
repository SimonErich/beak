---
title: Working with obers_ui
description: Pin obers_ui by git commit, bump the pin, and develop against a local checkout with melos run link-obers-ui.
type: guide
audience: [contributor]
status: stable
---

# Working with obers_ui

Beak's panel is built on obers_ui, and obers_ui is not on pub.dev: its own pubspec says `publish_to: 'none'`. Beak therefore depends on it by pinned git commit, so a plain clone of Beak resolves with nothing checked out beside it. This page covers the pin, how to bump it, and the one case where you want to override it: changing obers_ui and Beak together.

## At a glance

| You want to | Do this |
| --- | --- |
| Build Beak | `melos bootstrap`. Pub fetches obers_ui at the pinned commit. |
| Move to a newer obers_ui | Change the six `ref:` lines, then `melos bootstrap` and `dart test test/obers_ui_pin_test.dart`. |
| Edit obers_ui and Beak together | Clone obers_ui next to Beak, then `melos run link-obers-ui`. |
| Go back to the pin | `melos run unlink-obers-ui` |

## The pin

!!! warning "The current pin is behind"
    The pinned commit lacks obers_ui APIs that `beak_frontend` calls (the root `CHANGELOG.md` lists them under Known issues). `melos bootstrap` resolves, and then `flutter analyze` and every panel build fail. Until the pin moves to a pushed commit that has them, run `melos run link-obers-ui` before you touch anything that compiles the panel. The header of `.github/workflows/ci.yaml` names the CI jobs that stay red for the same reason.

Two pubspecs declare the dependency: `packages/beak_frontend`, which builds the panel on it, and `packages/beak`, whose `ui.dart` and `charts.dart` re-export it. No example declares it. A project reaches `OiIcons` and the rest of the widget set through `package:beak/ui.dart`, so it never adds an obers_ui dependency of its own.

Each pubspec declares three packages from one repository. Only the `ref` lines are elided below:

```yaml title="packages/beak_frontend/pubspec.yaml"
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui
      # ...
  obers_ui_autoforms:
    git:
      url: https://github.com/SimonErich/obers_ui
      path: packages/obers_ui_autoforms
      # ...
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui
      path: packages/obers_ui_charts
      # ...
```

Three details matter:

- **`ref` is a full 40-character commit SHA, not a branch.** A branch name would make every build a different build. `obers_ui_autoforms` and `obers_ui_charts` live in the same repository and are addressed with `path:`.
- **The three must agree, in both pubspecs.** They depend on each other inside the checkout, so a mismatch would resolve two copies of `obers_ui`. `test/obers_ui_pin_test.dart` fails if the SHAs diverge, if a ref is not a full SHA, or if anyone reintroduces a path dependency that leaves the repo.
- **This is a pre-1.0 arrangement.** When obers_ui publishes, the pins become ordinary version constraints and this page shrinks to nothing.

## Bump the pin

Update the `ref` in `packages/beak_frontend/pubspec.yaml` and in `packages/beak/pubspec.yaml`. Each declares three obers_ui packages, so that is six lines, all to the same SHA. Then resolve and run the pin test:

```bash
grep -n 'ref:' packages/beak_frontend/pubspec.yaml packages/beak/pubspec.yaml
melos bootstrap
dart test test/obers_ui_pin_test.dart
melos run analyze && melos run test
```

The `grep` should print six lines carrying one SHA. The commit has to exist on the obers_ui remote. One that lives only in your local checkout resolves for nobody else, and `melos bootstrap` is where you find out.

Bootstrapping rewrites the tracked lockfiles of the examples. Commit those changes with the bump.

## Develop against a local checkout

When you are changing obers_ui and Beak together, a pinned commit is the wrong thing: you want your working copy, hot-reloadable. Clone obers_ui next to the Beak repo and link it:

```bash
cd ..                                                    # next to beak/
git clone https://github.com/SimonErich/obers_ui.git
cd beak
melos run link-obers-ui
```

`link-obers-ui` runs `tool/link_obers_ui.dart` and then `melos bootstrap`. The tool looks for `../obers_ui` and writes path overrides for all three packages into the `pubspec_overrides.yaml` of every package that needs them. That means anything that declares an obers_ui package and anything that depends on `beak`, `beak_frontend` or `beak_serverpod_flutter`, because pub does not inherit a dependency's overrides. The pure Dart packages are left alone. It prints one line per package it changed:

```text
linked packages/beak_frontend (obers_ui, obers_ui_autoforms, obers_ui_charts)
linked packages/beak (obers_ui, obers_ui_autoforms, obers_ui_charts)
linked examples/quickstart (obers_ui, obers_ui_autoforms, obers_ui_charts)
Linked 3 packages against ../obers_ui.
```

That is the output from a trimmed copy of the repo. The full repo links every example, `packages/beak_serverpod_flutter`, and the Serverpod workspace root in `examples/serverpod`, whose members share the overrides of their root.

The block the tool writes sits under a marker comment, below the entries melos owns:

```yaml
# beak: linked obers_ui checkout
  obers_ui:
    path: ../../../obers_ui
  obers_ui_autoforms:
    path: ../../../obers_ui/packages/obers_ui_autoforms
  obers_ui_charts:
    path: ../../../obers_ui/packages/obers_ui_charts
```

Melos manages only the entries listed in each file's `# melos_managed_dependency_overrides:` header, so the block survives later bootstraps. Without a checkout the tool stops and says what to do:

```text
No obers_ui checkout at ../obers_ui.
Clone it next to this repo:
  git clone https://github.com/SimonErich/obers_ui.git ../obers_ui
```

When you are done, restore the pins:

```bash
melos run unlink-obers-ui
```

The script runs `dart run tool/link_obers_ui.dart --unlink` and then `melos bootstrap`, so run those two commands yourself if you do not have melos on the path. Unlinking removes only the block the tool wrote and leaves melos's entries in place. When that block was all a `pubspec_overrides.yaml` held, the file is deleted.

!!! warning "`melos run link-obers-ui -- --unlink` does not unlink"
    Melos 6.3.3 appends whatever follows `--` to the end of the whole script string. For `link-obers-ui` that is `dart run tool/link_obers_ui.dart && melos bootstrap --unlink`: the tool runs in link mode, and `melos bootstrap` receives a flag that was meant for the tool and stops with an error, after the packages are already linked. Unlinking is a script of its own, `unlink-obers-ui`, for that reason.

!!! tip "Why not melos's dependencyOverridePaths"
    Melos can apply overrides itself, but it applies them to every package in the workspace, including the pure Dart ones. That drags the Flutter SDK into `beak_core`, `beak_cli`, `beak_image` and the storage drivers, and makes `dart pub get` there require Flutter. `link-obers-ui` touches only the packages that depend on obers_ui.

## When obers_ui is missing something

If a Beak screen exposes a missing component behavior, fix it in obers_ui and add the regression test there. Beak binds domain state and permissions to the shared components, and an example configures those bindings. A wrapper in Beak or an example around every input or card is the fork this page exists to avoid. The `doc/` folder of the obers_ui checkout has its widget documentation.

## Rules and limits

- **The override files are git-ignored, the lockfiles are not.** `pubspec_overrides.yaml` never reaches a commit. The `pubspec.lock` of `examples/clean_beak_config`, `examples/foodio-adminpanel` and `examples/showcase` is tracked, and `pub get` writes the linked state into it while you are linked, so `path: "../../../obers_ui"` can ride along in a commit. Before you commit, run `melos run unlink-obers-ui` and then `git grep -ln 'path: "../../../obers_ui' -- '*pubspec.lock'`. It prints nothing when every tracked lockfile records the pin.
- **A link is per checkout.** Unlink before you tag a release, and before you compare behavior against CI, which always uses the pin.
- **`link-obers-ui` needs the sibling folder to be named `obers_ui`.** The path is `../obers_ui`, relative to the Beak root, and there is no option to change it.
- **The Serverpod workspace has its own resolution.** `examples/serverpod` is outside melos, so `melos bootstrap` does not resolve it. The link tool still writes its root overrides, and its README asks you to link once before running `dart pub get` there.

## Verify it

After a bump, all of these hold:

```bash
dart test test/obers_ui_pin_test.dart
```

```text
00:00 +18: All tests passed!
```

The count grows with the tests. Any `All tests passed!` line is the result.

While linked, the overrides are in place and point at the checkout:

```bash
grep -l 'linked obers_ui checkout' packages/*/pubspec_overrides.yaml examples/*/pubspec_overrides.yaml
```

After `melos run unlink-obers-ui`, the same command prints nothing.

## Reference

| Thing | Where |
| --- | --- |
| The pins | `packages/beak_frontend/pubspec.yaml`, `packages/beak/pubspec.yaml` |
| The pin test | `test/obers_ui_pin_test.dart` |
| The link tool | `tool/link_obers_ui.dart`, run by `melos run link-obers-ui` and `melos run unlink-obers-ui` |
| The sibling checkout | `../obers_ui`, relative to the Beak root |
| The marker the tool writes | `# beak: linked obers_ui checkout` |
| The obers_ui packages | `obers_ui`, `obers_ui_autoforms`, `obers_ui_charts` |
| Why `dependencyOverridePaths` is not used | the comment under `command: bootstrap:` in `melos.yaml` |

## Continue reading

- [Releasing](releasing.md) why the pin has to be linked out before a tag.
- [Dev infrastructure](dev-infrastructure.md) the other thing you set up locally.
- [Going to production](../shipping/going-to-production.md) the container images, which need no overrides.
- [Project structure](../start-here/project-structure.md) where `beak_frontend` and the examples sit in the tree.
