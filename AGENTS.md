# Beak: notes for agents working on the framework

This repository is Beak itself: the packages, the examples and the docs. Building an
app with Beak? Read the AGENTS.md in that app instead.

Claude Code: CLAUDE.md and .claude/ are git-ignored here. Keep a local CLAUDE.md
whose first line is `@AGENTS.md`, or Claude Code will not read this file. If the
repo root has a CLAUDE.md with the full build rules, read it too. It is the stricter
reading.

## Find before you write

- Use CodeGraph first when `.codegraph/` exists, then Read. Docs signatures can lag;
  source wins.
- Search for an existing widget, mapper or helper before adding one. Extend, do not fork.

## Layout

| Path | What |
| --- | --- |
| packages/beak_core | Pure Dart: columns, models, query spec, data-source seam, annotations, and the agent docs bundle in `doc/agent-docs` (generated) |
| packages/beak_frontend | The panel. obers_ui only |
| packages/beak_backend | Shelf server, WormDataSource, graph commits, policies, outbox, migration helpers |
| packages/beak | The umbrella libraries an app depends on (`beak.dart`, `panel.dart`, `server.dart`, ...) |
| packages/beak_cli | The `beak` CLI, including `beak agents` and `beak docs` |
| packages/beak_serverpod* | The Serverpod bridge: wire types, server engine, Flutter client and auth, generator |
| packages/beak_test, beak_image, beak_storage_* | Testing toolkit, image transforms, storage drivers |
| packages/worm* | Vendored ORM, outside the melos scope (`melos run test-worm`) |
| examples/quickstart | Byte-identical to `beak create quickstart` (`quickstart_parity_test`) |
| examples/clean_beak_config | The golden-path shop the docs quote |
| examples/serverpod | A real Serverpod 4 workspace with exact serverpod pins. Melos ignores it: run its tests by hand |
| docs/ | MkDocs source. `docs/_internal` and `docs/_agents` are unpublished |
| tool/ | The gates |

## Rules that fail review

- UI is obers_ui. Never import material.dart or cupertino.dart (`guard-material`). Widgets
  are HookWidget, never StatefulWidget or State (`guard-hooks`); state is Signals, DI is
  GetIt, routing is go_router.
- No `dynamic` (except `// interop:`), no `as` casts, no `Map<String, dynamic>` in a domain
  or public API. Beak users never write a string field reference and never touch
  `dynamic`; an API that forces either gets redesigned.
- Backend: Handler -> Service -> DataSource; the handler maps typed exceptions.
  Frontend: Widget -> ViewModel -> Repository -> DataSource; ViewModels never try/catch.
- beak_core and beak_frontend never reach dart:io or server packages (`guard-web`).
- Every public member has a doc comment. No print, no TODO, no commented-out code.
- Pre-1.0: remove a superseded API instead of deprecating it. Record the break under
  CHANGELOG.md [Unreleased] and add a row to the corrections table in docs/ai/index.md.

## Test first

One failing test, the least code that passes, then refactor. Every fix ships its
regression test. Fakes over mocks. Details: docs/contributing/writing-tests.md.

## Regenerate, never hand-edit

| You changed | Run |
| --- | --- |
| A beak_cli emitter | `dart run ../../packages/beak_cli/bin/beak.dart prepare` in each example; commit the output |
| The scaffold in create_command.dart | Recreate examples/quickstart |
| The block templates in docs/_agents/blocks | `melos run agent-docs` |
| docs/, a file docs quote with `--8<--`, CHANGELOG.md | `melos run agent-docs` |
| packages/*/skills | `dart test test/published_skills_test.dart` |

## The gate

`melos run analyze`, `melos run format-check`, `melos run test`, `melos run coverage`;
`melos run test-e2e` after `melos run up`; `melos run test-worm` when packages/worm*
changed. Melos is pinned to 6.3.3.

## Docs

Prose follows docs/_internal/STYLE_GUIDE.md: no em-dashes, no "simply", no "just <verb>",
no question headings. Quote code with `--8<-- "path:section"` instead of copying it. Every
page has front matter (title and description) and a nav entry. Skills in packages/*/skills
are workflows, not reference: name `<package-with-hyphens>-<verb>`, description under
1024 characters, body under 150 lines.

## Commits

Conventional Commits with a package scope: `feat(beak_cli): add beak agents`. Never
commit CLAUDE.md, .claude/, PLAN/, PROMPT.md or *.db files.
