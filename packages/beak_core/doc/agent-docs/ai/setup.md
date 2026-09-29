# Set up your agent

> Give a coding agent the AGENTS.md block, CLAUDE.md, workflow skills and version-matched docs in a Beak project, and check that it reads them.

For coding agents and the people who install them. Humans: see [Installation](../start-here/installation.md). One command, `beak agents`, writes everything an agent needs in a Beak project: a managed block in `AGENTS.md`, a `CLAUDE.md` that imports it, a copy of the docs that matches the resolved Beak version, and the workflow skills. `beak create`, `beak init` and `beak prepare` run it for you.

## Rules

- MUST run `beak agents` (or `beak prepare`) after every change of the Beak version. The block, the docs copy and the skills name the version they were written for.
- MUST commit `AGENTS.md`, `CLAUDE.md` and the skill folders. NEVER commit `.dart_tool/`: the docs copy lives there and `beak docs` recreates it.
- NEVER edit between `<!-- BEGIN:beak-agent-rules -->` and `<!-- END:beak-agent-rules -->`. Beak rewrites that span. Project conventions go above or below it.
- MUST run `beak agents --check` in CI. It writes nothing and exits `1` when `AGENTS.md`, `CLAUDE.md` or a skill would change. The docs copy is not counted, because it is not committed.
- NEVER delete one marker. A damaged pair stops Beak with exit `1` and a message; it does not guess.
- MUST keep `AGENTS.md` under 32 KiB. `beak doctor` warns above it, since Codex reads no more.
- MUST read `.dart_tool/beak/docs/ai-index.md` before writing Beak code, and MUST NOT rely on a signature remembered from another Beak version.

## What gets written

| File or folder | Written by | Holds | Commit it |
| --- | --- | --- | --- |
| `AGENTS.md` | `beak agents`, `create`, `init`, `prepare` | The managed block between the two markers. Everything outside the markers is yours and stays byte for byte | yes |
| `CLAUDE.md` | the same | One line, `@AGENTS.md`, so Claude Code loads the block | yes |
| `.dart_tool/beak/docs/` | `beak docs`, `beak agents`, `beak prepare` | The docs bundle of the resolved `beak_core`, starting at `ai-index.md` | no |
| `.claude/skills/`, `.agents/skills/`, `.cursor/skills/` | `beak agents`, `create`, `init` | The workflow skills, one folder each, with a `.beak-skill.json` sidecar | yes |
| `AGENTS.md` at the workspace root | `beak agents` | In a pub workspace: a short block that sends the agent to the admin package's `AGENTS.md` | yes |

`prepare` refreshes the block and the docs copy. It does not install skills. `dev`, `migrate` and `seed` write none of this.

## Which command to run

| Situation | Run | Result |
| --- | --- | --- |
| New project | `beak create acme --authored` | Scaffold, `AGENTS.md`, `CLAUDE.md`, skills and docs in one go |
| Existing Flutter app | `beak init` | Adds Beak, then the same agent files |
| Existing Beak project, first time or after an upgrade | `beak agents` | Writes or updates all four |
| Docs copy missing (fresh clone, `pub get` ran) | `beak docs` | Recreates `.dart_tool/beak/docs/` |
| CI gate | `beak agents --check` | Exit `1` when a committed file is out of date |
| Preview | `beak agents --dry-run` | Prints what would change, writes nothing |
| Project keeps its own instruction file | `beak agents --print` | Prints the block for you to paste |
| Remove everything Beak wrote | `beak agents --remove` | Strips the block, deletes an import-only `CLAUDE.md`, uninstalls unedited skills |

A run in a fresh scratch project, real output:

```console
$ beak agents --remove
  agents   CLAUDE.md deleted · AGENTS.md stripped
  skills   .claude/skills: 7 removed
  skills   .agents/skills: 7 removed
$ beak agents --check
  would append the block to AGENTS.md
  would create CLAUDE.md
  docs     Beak 0.9.0
  skills   .claude/skills: 7 to be installed
  skills   .agents/skills: 7 to be installed
  run `beak agents` to bring them up to date
$ echo $?
1
$ beak agents
  agents   AGENTS.md appended · CLAUDE.md created
  docs     Beak 0.9.0
  skills   .claude/skills: 7 installed
  skills   .agents/skills: 7 installed
$ beak agents
  agents   up to date
  docs     Beak 0.9.0
  skills   .claude/skills: 7 up to date
  skills   .agents/skills: 7 up to date
```

A second run writes nothing. The skill count is seven in a project that depends on `beak`; `beak-serverpod-setup` is the eighth, and it appears when `beak_serverpod` is among the resolved packages. Without `flutter pub get` there is no resolved package. `beak agents` still writes the block, then prints the reason and the fix:

```console
$ beak agents
  agents   AGENTS.md appended · CLAUDE.md created
  docs     not materialized: .dart_tool/package_config.json not found; run `flutter pub get` first
  skills   not installed: run `flutter pub get`, then `beak agents`
```

## The managed block

Beak owns the span between the markers. This is the block of a generated project, exactly as `beak create` writes it (`examples/quickstart/AGENTS.md` is byte-identical to the scaffold):

```markdown title="examples/quickstart/AGENTS.md"
<!-- BEGIN:beak-agent-rules -->
## Beak

This is a Beak 0.9.0 admin panel, and Beak moves faster than your
training data. Read `.dart_tool/beak/docs/ai-index.md` before writing Beak code: it routes each
task to the page that covers it and lists the APIs you probably remember
wrong. Folder missing? Run `beak docs`.

- Schemas live in `lib/resources/*/models/*.dart`. After editing one, run `beak prepare`.
  Never edit `*.beak.dart` or `lib/beak/*.g.dart`.
- `lib/main.dart` is generated. Panel presentation lives in `beak.yaml`;
  `beak eject main` hands the entrypoint over to you.
- Reference fields through the generated model (`ProductModel.name`), never a
  string. No `dynamic`, no `as` casts.
- UI is obers_ui (`package:beak/ui.dart`). Never import
  `package:flutter/material.dart` or `cupertino.dart`. Widgets are `HookWidget`.
- Business rules go on the schema (`behavior`, `validationRules`), never in a
  widget callback. The server re-runs them on every save.
- Never edit a migration that already ran. Change a shipped table with
  `beak make:migration <Name> --from-drift`, review it, then `beak migrate`.
- `beak dev` serves the API only. Run the panel yourself with
  `flutter run -d chrome` in a second terminal.
- Done means `beak doctor`, `dart format .`, `flutter analyze` and
  `flutter test` are all clean.

Workflow skills: run `beak agents` to install them.
<!-- END:beak-agent-rules -->
```

The last line lists the installed skills by name once `beak agents` has installed them. The text comes from one of four templates, chosen by what the project depends on:

| Kind | Chosen when | What differs |
| --- | --- | --- |
| Standalone | The project depends on `beak` and boots from `lib/main.dart` | Says whether `lib/main.dart` is generated (`beak eject main` hands it over) or registers each `BeakResource` |
| Embedded | `panel.entrypoint` in `beak.yaml` names a file other than `lib/main.dart` | Scopes the rules to Beak files, names the entrypoint and the `flutter run -t` command, and leaves the app's own conventions alone |
| Serverpod admin | The project depends on `beak_serverpod_flutter` and reaches the server through the tunnel: it uses `serverpodBeakDataSource`, or a package of its workspace depends on `beak_serverpod_server`. A client bridge app, which borrows the package for its sign-in screens alone, gets the standalone or embedded block instead | Names the server, client and schema packages, says Serverpod owns the database and its migrations, and tells the agent never to start the server |
| Workspace root | The project is a member of a pub workspace | Points at the admin package's `AGENTS.md` |

The templates ship in the docs bundle under `_agents/blocks/`, so a project gets the rules of the Beak version it resolved. The CLI carries the same four as a fallback for a project with no bundle yet. `beak agents --print` renders the block for the current project without writing.

## CLAUDE.md pairing

Claude Code loads `CLAUDE.md`. `AGENTS.md` reaches it through an `@AGENTS.md` import, so Beak decides per directory:

| State of the directory | Beak does |
| --- | --- |
| No `CLAUDE.md` and no `.claude/CLAUDE.md` | Creates `CLAUDE.md` containing `@AGENTS.md` |
| `CLAUDE.md` already imports `AGENTS.md`, or both are one file (a link) | Leaves it |
| `CLAUDE.md` exists without the import | Writes the same managed block into `CLAUDE.md`, between the same markers, and leaves the rest |
| Only `.claude/CLAUDE.md` exists | Leaves it. `beak doctor` warns when it does not read `AGENTS.md`; inside `.claude/` the import must be `@../AGENTS.md` |

Run against a `CLAUDE.md` that held two lines of team rules, Beak appended the block and kept the lines:

```console
$ beak agents
  agents   AGENTS.md created · CLAUDE.md appended
  docs     Beak 0.9.0
  skills   .claude/skills: 7 installed
  skills   .agents/skills: 7 installed
```

Damage one marker and the next run refuses to write that file:

```console
$ beak agents
  agents   up to date
  docs     Beak 0.9.0
  skills   .claude/skills: 7 up to date
  skills   .agents/skills: 7 up to date
  ! AGENTS.md: the BEGIN marker has no END marker; fix or delete the markers in the file
```

The exit code is `1`. `beak doctor` reports the same text as a warning.

## Skills

Eight workflow skills ship inside the packages and are versioned with them. A skill is a workflow with a verification gate and an example prompt; the knowledge stays in the docs.

| Skill | Package | Use it for |
| --- | --- | --- |
| `beak-add-resource` | `beak` | A new table with its list and form screens |
| `beak-evolve-schema` | `beak` | Changing a table that already shipped, with its migration |
| `beak-adopt-database` | `beak` | An admin over a database that exists (`beak introspect`) |
| `beak-add-business-rule` | `beak` | A rule that must hold on every save: validation, derived values, named actions |
| `beak-secure-api` | `beak` | Roles, row scopes, read-only fields, hidden columns |
| `beak-upgrade` | `beak` | Moving a project to a newer Beak release |
| `beak-frontend-build-screens` | `beak_frontend` | Table, form, wizard and dashboard layout |
| `beak-serverpod-setup` | `beak_serverpod` | An admin app inside a Serverpod 4 workspace |

Each skill installs to `<workspace root>/<target>/skills/<name>/` for every target. The targets come from `--skills claude,agents,cursor` or `none`, then from `agents.skills` in `beak.yaml`, then from the agent folders the workspace already has, else `claude` and `agents`. Beak knows a skill is its own by the `.beak-skill.json` next to it (`package`, `version`, `sha256`). A skill nobody edited is replaced when the package ships a new one and removed when no package ships it any more. A skill you edited is kept, and `--force` replaces it. A skill that the `skills` CLI manages is skipped. [Prompt recipes](prompts.md) has an example prompt per skill.

## beak.yaml

Three keys under `agents:` turn parts off, and `--[no-]instructions`, `--[no-]docs` and `--skills` override them for one run.

| Key | Values | Effect |
| --- | --- | --- |
| `agents.instructions` | `all`, `package`, `none` | `all`: the project's files and the workspace root's. `package`: the project's only. `none`: Beak never touches `AGENTS.md` or `CLAUDE.md` |
| `agents.docs` | `true`, `false` | `false` stops `prepare` and `agents` from copying the docs |
| `agents.skills` | list of `claude`, `agents`, `cursor` | Where skills go. `[]` installs none |

Reference: [beak.yaml](../reference/beak-yaml.md#agents).

## Pub workspaces and Serverpod

In a pub workspace (a Serverpod project is one), the docs copy and the skills go to the workspace root, once for all members. The admin package gets its own block, and with `agents.instructions: all` the root gets the short workspace block. Use `--root <dir>` when the workspace root cannot be found by walking up. A package that depends on `beak_core` alone (shared schema classes) has no app to describe: `beak agents` prints one line saying so and exits `0`.

## Check that the agent reads the docs

| Check | Command or prompt | Passes when |
| --- | --- | --- |
| Files are current | `beak agents --check` | Exit `0` |
| Project health, agent group included | `beak doctor` | `AGENTS.md has the Beak 0.9.0 block`, `CLAUDE.md reads AGENTS.md`, `docs bundle for Beak 0.9.0 is in .dart_tool/beak/docs`, `7 Beak skills installed, all current` |
| The docs copy is the resolved version | `beak docs --json` | `version` equals the version in `pubspec.lock` for `beak_core` |
| The agent saw the block | Ask it to state the Beak version `AGENTS.md` names and the folder it says to read first | It answers `0.9.0` and `.dart_tool/beak/docs/ai-index.md` without opening a file |
| The agent reads before it writes | Ask for a change, then read its tool calls | It opens `ai-index.md` and one page from the task map before the first edit |
| The agent dropped the old APIs | Ask it to add a metric card to a dashboard | It uses `BeakMetricBlock` and does not write `BeakKpiBlock` |

A real `beak doctor` run of the agent group:

```console
$ beak doctor
  ...
  OK   AGENTS.md has the Beak 0.9.0 block
  OK   CLAUDE.md reads AGENTS.md
  OK   AGENTS.md is 2 KiB
  OK   docs bundle for Beak 0.9.0 is in .dart_tool/beak/docs
  OK   7 Beak skills installed, all current
  OK   CLI 0.9.0 matches project Beak 0.9.0
All checks passed.
```

## Machine-readable twin

This page as Markdown: `https://simonerich.github.io/beak/ai/setup/index.md`. In a project that ran `beak docs`: `.dart_tool/beak/docs/ai/setup.md`. [Machine-readable docs](machine-readable-docs.md) explains both.

## Continue reading

- [Rules for agents](rules.md): the MUST and NEVER list the block summarises.
- [Prompt recipes](prompts.md): prompts per starting situation and per skill.
- [Machine-readable docs](machine-readable-docs.md): the bundle this page copies into `.dart_tool`.
- [CLI commands](../reference/cli-commands.md#beak-agents): every flag of `beak agents` and `beak docs`.
