---
name: beak-upgrade
description: >-
  Upgrade a Beak project to a newer release: move every Beak dependency to the
  same git ref, reactivate the beak CLI at that tag, regenerate, read the
  CHANGELOG entries in between, apply each breaking change, refresh the agent
  instructions, docs and skills, and prove the project builds and passes. Use
  when asked to update or bump Beak, when beak doctor reports a CLI and project
  version mismatch, or when a Beak change breaks the build after pub get. Not
  for changing your own schema or database (beak-evolve-schema).
---

# Upgrade Beak

Beak is pre-1.0. A release removes the API it replaces instead of deprecating
it, so an upgrade is a list of breaking changes to apply, in an order that keeps
the analyzer useful. Every Beak package, and the `beak` CLI, must be on the same
release.

## Steps

1. Work on a clean branch. Note where you start: `"beak"` in
   `.dart_tool/beak/docs/manifest.json` is the project's Beak version and
   `beak --version` is the CLI's. Read
   `.dart_tool/beak/docs/start-here/upgrading.md` now: after the upgrade that
   folder holds the new release's text, so keep what you need from the old one.
2. Pick the target tag (for example `v0.10.0`) and set it as the `ref:` of every
   Beak dependency. Find them all with
   `grep -rn "SimonErich/beak" --include=pubspec.yaml .`: the app's `beak`, or
   `beak_core`, `beak_frontend`, `beak_serverpod*` in a Serverpod workspace, in
   every workspace member. Mixed refs cause resolution errors that read like
   Beak bugs. In a Serverpod workspace also check the serverpod pins against
   `.dart_tool/beak/docs/serverpod/versions.md`.
3. Reactivate the CLI at the same tag:
   `dart pub global activate --source git https://github.com/SimonErich/beak.git --git-path packages/beak_cli --git-ref v0.10.0`.
   `beak --version` must now equal the project's version.
4. Run `flutter pub get` (`dart pub get` in a pure Dart workspace).
5. Run `beak prepare`. It regenerates every `*.beak.dart` part and `lib/beak/*.g.dart`
   file, refreshes the AGENTS.md block and copies the new docs to
   `.dart_tool/beak/docs`. What it reports is a change in what schema classes
   or `beak.yaml` may declare: fix each issue before anything else.
6. Read `.dart_tool/beak/docs/changelog.md` from your starting version to the
   new one, and the corrections table in `.dart_tool/beak/docs/ai-index.md`.
   List every Removed and Changed entry that touches a symbol the project uses
   (`grep -rn "<symbol>" lib test`). Apply them in this order: schema classes
   and annotations, resource classes and screens, `lib/server.dart` and
   migrations, tests. Replace a removed API with its documented successor; do
   not write a local shim, and do not pin the old release to avoid the work.
7. Run `flutter analyze` and repair errors one category at a time, then
   `dart format .`. A generated file that fails to compile is a sign that
   step 5 did not run or failed: rerun `beak prepare` before touching it.
8. Run `beak agents` to refresh the instructions block, the docs and the
   installed skills (`beak agents --check` exits 1 while anything is stale, for
   CI). Skills you edited locally are kept; `--force` replaces them.
9. See whether the release added migrations of Beak's own tables (receipts,
   outbox): `beak migrate status`. Back up the database,
   then `beak migrate`. Do not touch your own applied migrations.
10. Run `beak doctor` and `flutter test`. Doctor's "CLI matches project Beak"
    line must pass.
11. Report the old and new versions, every breaking change you applied (symbol,
    replacement, files), and anything you could not resolve.

## Gate

`beak doctor` passes with matching versions, `dart format .`, `flutter analyze`
and `flutter test` are clean, and `beak agents --check` exits 0.

## Example prompt

```text
Use the beak-upgrade skill to move this project to Beak v0.10.0 and list every breaking change you applied.
```
