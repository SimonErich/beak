# Working with obers_ui

> Pin obers_ui by git commit and develop against a local checkout when you need to.

Beak's panel is built on obers_ui, which is not published on pub.dev. Beak
depends on it by **pinned git commit**, so cloning Beak on its own is enough:
`melos bootstrap` fetches obers_ui into the pub cache and the workspace
resolves. Nothing has to be checked out beside the repo.

This page explains the pin and the one case where you want to override it.

> **Note: This used to be a caveat**
>
> Earlier versions of Beak declared obers_ui as a path dependency climbing
> above the repo root (`../../../obers_ui`). That made a fresh clone fail to
> resolve, forced CI to check out two repositories, and required a
> build-time override file for container images. All of that is gone; if you
> are following an older guide that mentions a sibling checkout or
> a web-overrides file for the container images, it is out of date.

## The pin

Two pubspecs declare the dependency: `packages/beak_frontend`, which builds the
panel on it, and `packages/beak`, whose `ui.dart` and `charts.dart` re-export
it. No example declares it. A project reaches `OiIcons` and the rest of the
widget set through `package:beak/ui.dart`, so it never adds an obers_ui
dependency of its own.

```yaml title="packages/beak_frontend/pubspec.yaml"
dependencies:
  # ...
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui
      ref: c956d25634c93e23847ec5a4150c1d62fe3a7c90
  obers_ui_autoforms:
    git:
      url: https://github.com/SimonErich/obers_ui
      path: packages/obers_ui_autoforms
      ref: c956d25634c93e23847ec5a4150c1d62fe3a7c90
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui
      path: packages/obers_ui_charts
      ref: c956d25634c93e23847ec5a4150c1d62fe3a7c90
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

Update the `ref` in both pubspecs, `packages/beak_frontend` and `packages/beak`.
Each declares three obers_ui packages, so that is six lines. Then re-bootstrap:

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
every Flutter package or example that depends on the Beak UI, including transitive consumers, and re-bootstraps. All three Obers packages are overridden together, so applications do not accidentally mix local widgets with cached charts or autoforms.
Melos manages only the entries listed in each file's
`# melos_managed_dependency_overrides:` header, so these survive later
bootstraps. When you are done:

```bash
melos run link-obers-ui -- --unlink
```

The override files are git-ignored, so a link never leaks into a commit.

> **Tip: Why not melos's dependencyOverridePaths**
>
> Melos can do this itself, but it applies the overrides to *every* package
> in the workspace, including the pure-Dart ones. That drags the Flutter SDK
> into `beak_core`, `beak_cli`, `beak_image` and the storage drivers, and
> makes `dart pub get` there require Flutter. `link-obers-ui` touches only
> the packages that actually depend on obers_ui.

## Application themes

`BeakPanel.theme` and `darkTheme` take Obers theme data. Prefer semantic colors, typography and component theme settings over application wrappers around each input or card. The Foodio example keeps its palette, typography and icon choices under `lib/theme/`; the resource definitions consume the same table, form, summary and command components as other Beak panels.

When a prototype exposes a missing component behavior, extend the shared Obers component and add its interaction or layout regression there. Beak should bind domain state and permissions; an example should configure those bindings.

## Continue reading

- [Going to production](../shipping/going-to-production.md) the container images, which now
  need no dependency overrides at all.
- [Installation](../start-here/installation.md) getting a Beak workspace
  resolved.
- [Project structure](../start-here/project-structure.md) where `beak_frontend`
  and the examples sit in the tree.
