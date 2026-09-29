---
title: beak.yaml
description: Every key of the project file, its default, the command that reads it, and what each way of booting the panel does with it.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# beak.yaml

`beak.yaml` holds the decisions that are neither schema nor Dart: what the panel is called, where it calls, where the server binds, which file boots the panel, what coding agents get, and how the default resources appear in the sidebar. Every key is optional. Delete the file and Beak still boots, titling the panel after the package.

## Import

`beak.yaml` is not imported. It sits next to `pubspec.yaml` and is read by the CLI, at generate time, never by the running panel or server:

| Reader | Uses |
| --- | --- |
| `beak prepare` (and every command that runs it first) | all keys; writes the results into `lib/beak/*.g.dart` |
| `beak dev`, `beak doctor`, `beak make:resource` | `panel.entrypoint` |
| `beak eject`, `beak create --authored`, `beak init` | `name`, `api`, `theme`, `resources`, written once into an authored entrypoint |
| `beak prepare`, `beak agents`, `beak doctor` | `agents` |

A missing file, an empty file or a file of only comments means the defaults. The root must be a mapping. Unknown keys are errors, not silent no-ops: a typo that does nothing is worse than one that stops generation.

```dart title="packages/beak_cli/lib/src/project/beak_project_config.dart"
--8<-- "packages/beak_cli/lib/src/project/beak_project_config.dart:beakYamlKeys"
```

## Summary

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| [`name`](#name) | string | the title-cased package name | Panel title |
| [`api.baseUrl`](#api) | string | `http://localhost:8080` | The origin the panel calls, or `auto` |
| [`server.port`](#server) | int, 1 to 65535 | none (`8080`) | Default port of the generated server |
| [`server.host`](#server) | string | none (`0.0.0.0`) | Default interface of the generated server |
| [`panel.entrypoint`](#panel) | Dart path | none (`lib/main.dart` is Beak's) | The file that boots the panel, in an app that keeps its own `lib/main.dart` |
| [`agents.instructions`](#agents) | `all`, `package`, `none` | `all` | Which `AGENTS.md` files Beak keeps its block in |
| [`agents.docs`](#agents) | bool | `true` | Copy the version-matched docs to `.dart_tool/beak/docs` |
| [`agents.skills`](#agents) | list of `claude`, `agents`, `cursor` | not set | Where skills are installed; `[]` installs none |
| [`theme.sidebar.collapsible`](#theme) | bool | `true` | The sidebar can collapse to an icon rail |
| [`theme.sidebar.startCollapsed`](#theme) | bool | `false` | It starts collapsed |
| [`resources.<table>.icon`](#resources) | lowerCamelCase string | `table` | `OiIcons` name of the sidebar icon |
| [`resources.<table>.label`](#resources) | string | the model's label | Page and navigation title |
| [`resources.<table>.section`](#resources) | string | none | Sidebar group heading |
| [`resources.<table>.hidden`](#resources) | bool | `false` | Keep the default resource out of the sidebar |

The shop, in full:

```yaml title="examples/clean_beak_config/beak.yaml"
name: Clean Beak Shop
api:
  baseUrl: http://localhost:8080
resources:
  order_items:
    hidden: true
  order_discounts:
    hidden: true
  user_profile_connections:
    hidden: true
```

## What each way of booting reads

A panel boots one of two ways, see [Two ways to boot a panel](../start-here/generated-or-authored.md). The generated panel is rebuilt from `beak.yaml` on every `beak prepare`. An authored entrypoint is written once, from `beak.yaml`, by `beak eject main`, `beak create --authored` or `beak init`, and after that it is yours: editing `beak.yaml` no longer changes it.

| Key | Generated `lib/main.dart` | Authored `lib/main.dart` or `panel.entrypoint` |
| --- | --- | --- |
| `name` | `lib/beak/panel.g.dart`, on every `prepare` | Copied into `BeakPanel(title:)` once |
| `api.baseUrl` | `panel.g.dart`, on every `prepare` | Copied into `apiBaseUrl:` once (omitted when it is the default) |
| `theme.sidebar.*` | `panel.g.dart` | Copied into a `BeakPanelConfig` once, only when not the default |
| `resources.<table>` | The default resource of each model without a `BeakResource` class | Written into the resource list once. A later edit changes nothing; edit the `BeakResource` in your file |
| `server.*` | `lib/beak/server.g.dart` | Same file, the backend does not depend on the panel bootstrap |
| `panel.entrypoint` | Not used | Tells `prepare` not to write `lib/main.dart`; `dev` prints `-t <file>` |
| `agents.*` | Read by every command that touches agent files | Same |

Two things are still checked in an authored project on every `prepare` and `doctor`: the file must parse, and every `resources.<table>` key must name a discovered table.

## `name`

```yaml
name: Acme Admin
```

The panel title, in the shell and the browser tab. Quoted into generated Dart with `'`, `\` and `$` escaped. The default is `BeakProjectConfig.titleCase(<package name>)`: `acme_admin` becomes `Acme Admin`.

## `api`

```yaml
api:
  baseUrl: http://localhost:8080
```

`baseUrl` is a string, not validated further. It becomes a compile-time default the panel reads, so one build can point elsewhere without touching the file:

```dart
const String.fromEnvironment(
  'BEAK_API_BASE_URL',
  defaultValue: 'http://localhost:8080',
)
```

```bash
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

With `baseUrl: auto` the generated panel calls the origin it was served from (`kIsWeb ? Uri.base.origin : 'http://localhost:8080'`), which is right when one host serves both halves. `auto` ignores `BEAK_API_BASE_URL`.

## `server`

```yaml title="examples/foodio-adminpanel/beak.yaml"
server:
  port: 8081
```

`port` (integer, 1 to 65535) and `host` (string) are defaults for the generated host, written into `lib/beak/server.g.dart` as `{'PORT': '8081', ...environment}`. A real `PORT` or `HOST` in the environment or `.env` still wins, because where a process binds is a deployment decision. Use it when a project has a fixed development port; two Beak apps in one repository cannot both take 8080.

## `panel`

```console
$ cat beak.yaml
name: Fapp

api:
  baseUrl: http://localhost:8080

panel:
  # This app keeps its own lib/main.dart, so `beak prepare` never writes it.
  # The panel boots from this file instead: flutter run -t lib/admin_main.dart
  entrypoint: lib/admin_main.dart
```

That is what `beak init` writes. `entrypoint` is a Dart file path relative to the project root: it must end in `.dart`, not start with `/`, contain no backslash and no `..` segment (`beak init --entrypoint` is stricter and takes only a file directly under `lib/`).

With it set:

- `beak prepare` writes every generated file except `lib/main.dart`, and does not compare it.
- `beak dev` prints `flutter run -d chrome -t lib/admin_main.dart`.
- `beak doctor` checks that this file lists every `BeakResource` class, and that no file it reaches imports the server.
- `beak make:resource` prints the line to add to that file's `resources: [...]`.
- `beak agents` writes the embedded variant of the `AGENTS.md` block.

Without it, `lib/main.dart` is the entrypoint. It is Beak's until you run `beak eject main`.

## `agents`

```yaml
agents:
  instructions: package
  docs: true
  skills: [claude, cursor]
```

What Beak writes for coding agents. Every default is on; a project that would rather keep agent files out of its tree says so here and Beak stops.

| Key | Values | Effect |
| --- | --- | --- |
| `instructions` | `all`, `package`, `none` | The enum below. `beak agents --[no-]instructions` overrides it for one run |
| `docs` | bool | `false` stops `prepare` and `agents` from copying the docs to `.dart_tool/beak/docs`. `--[no-]docs` overrides it |
| `skills` | list of `claude`, `agents`, `cursor` | Folders (`.claude/skills`, `.agents/skills`, `.cursor/skills`) `beak agents` installs skills into. `[]` never installs. Not set: the agent folders the workspace already has, else `claude` and `agents`. `--skills` overrides it |

```dart title="packages/beak_cli/lib/src/project/beak_project_config.dart"
--8<-- "packages/beak_cli/lib/src/project/beak_project_config.dart:BeakAgentInstructions"
```

`prepare` refreshes the `AGENTS.md` block and the docs copy but does not install skills; `beak agents`, `beak create` and `beak init` do. See [CLI commands](cli-commands.md#beak-agents).

## `theme`

```yaml
theme:
  sidebar:
    collapsible: true
    startCollapsed: false
```

The two sidebar behaviours. Both are booleans; both default as shown, so a panel that wants neither can leave the block out. Anything else about the look of the panel is Dart, in `lib/theme.dart` (`beak eject theme`), see [Theming basics](../theming/theming-basics.md).

## `resources`

```yaml
resources:
  notes:
    icon: fileText
    label: Notes
    section: Content
  order_items:
    hidden: true
```

Keyed by **table name**, which is what `@Resource(table:)` says, or what Beak derived from the class name. The four keys shape the default resource that the generated panel makes for a model:

| Key | Becomes | Notes |
| --- | --- | --- |
| `icon` | `BeakIconToken(OiIcons.<icon>)` | Must be lowerCamelCase (`^[a-z][A-Za-z0-9]*$`). Whether the name exists in `OiIcons` is checked by the compiler, on the generated file |
| `label` | `title:` | Page title, and the sidebar title unless the resource sets `navigationTitle` |
| `section` | `navigationGroup:` | Sidebar group heading |
| `hidden` | the model gets no default resource | The model keeps its table, its API and its relationships. It only loses a sidebar entry |

A model with its own `BeakResource` class ignores all four: the class replaces the default, so set `icon`, `title` and `navigationGroup` there, see [Panel and resource options](panel-options.md). A resource class is always shown, so `beak eject resource <table>` refuses a table with `hidden: true`. The same applies to the authored entrypoint: the keys were applied once, when it was written.

A key that names no discovered table stops `prepare` and fails `doctor`.

## Errors

Every problem names the key. Real messages:

| Input | Message |
| --- | --- |
| `nme: x` | `beak.yaml: unknown key "nme". Expected one of: agents, api, name, panel, resources, server, theme.` |
| `api: {baseUrl: 1}` | `beak.yaml: api.baseUrl must be a string (got 1).` |
| `server: {port: 99999}` | `beak.yaml: server.port must be a port number between 1 and 65535, got "99999".` |
| `panel: {entrypoint: "/abs.dart"}` | `beak.yaml: panel.entrypoint must be a Dart file path relative to the project, such as "lib/admin_main.dart" (got "/abs.dart").` |
| `agents: {instructions: some}` | `beak.yaml: agents.instructions must be one of: all, package, none (got "some").` |
| `agents: {skills: [vscode]}` | `beak.yaml: agents.skills has "vscode"; expected claude, agents or cursor.` |
| `resources: {notes: {colour: red}}` | `beak.yaml: unknown key "resources.notes.colour". Expected one of: hidden, icon, label, section.` |
| `resources: {notes: {icon: file-text}}` | `beak.yaml: resources.notes.icon must be a lowerCamelCase OiIcons name (got "file-text").` |
| `theme: {sidebar: {collapsible: maybe}}` | `beak.yaml: theme.sidebar.collapsible must be true or false (got maybe).` |
| `resources: {notez: {icon: fileText}}` | `Cannot generate — fix these first:` then `beak.yaml: resources.notez names no discovered table — did you mean notes?.` |
| invalid YAML | `beak.yaml: line 2, column 1: While parsing a flow sequence, expected ',' or ']'.` (1-based) |

All exit `1`. `beak doctor` reports the same text as a `FAIL` line and stops there.

## Rules and limits

- What does not live here: a resource's filters, actions, screens and layouts (a `BeakResource` class), auth and policy (`lib/server.dart`, `lib/auth.dart`), the theme (`lib/theme.dart`), the database URL and storage (environment variables, see [Configuration and environment](configuration.md)). `beak eject <target>` writes the starter for each.
- Nothing in `beak.yaml` reaches the running panel or server after generation except through the generated Dart. Changing it needs `beak prepare` (`beak dev` runs it), and for an authored entrypoint an edit of that file.
- Only the four `resources` keys above exist; any other key under a table is an error.
- `server` sets defaults, never overrides.

## Source

- `packages/beak_cli/lib/src/project/beak_project_config.dart` parses and validates the file (`BeakProjectConfig`, `BeakApiSettings`, `BeakServerSettings`, `BeakPanelSettings`, `BeakAgentSettings`, `BeakResourceOverride`) and reports keys that name no table.
- `packages/beak_cli/lib/src/project/beak_emitters.dart` turns it into `panel.g.dart`, `server.g.dart` and the authored entrypoint.
- `packages/beak_cli/lib/src/commands/init_command.dart` writes `panel.entrypoint`.
- `examples/clean_beak_config/beak.yaml`, `examples/foodio-adminpanel/beak.yaml` and `examples/quickstart/beak.yaml` are real files.

## Continue reading

- [Configuration and environment](configuration.md) the environment variables and backend settings that beak.yaml does not hold.
- [CLI commands](cli-commands.md) the commands that read it.
- [Panel and resource options](panel-options.md) the same decisions in Dart, per resource.
- [Project structure](../start-here/project-structure.md) what each folder and file of a project is for.
