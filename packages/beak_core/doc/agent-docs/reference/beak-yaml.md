# beak.yaml

> Look up every key of the project file and what happens when you leave it out.

`beak.yaml` holds the decisions that are presentation rather than code: what
the panel is called, where it calls, and how each discovered resource appears
in the sidebar. Every key is optional. Delete the file and Beak still boots,
titling the panel after the package.

[See the maintained shop configuration](https://github.com/SimonErich/beak/tree/v0.9.0/examples/clean_beak_config).

## Top level

| Key | Default | What it decides |
| --- | --- | --- |
| `name` | the title-cased package name | The panel's title, in the shell and the browser tab |
| `api` | see below | Where the panel sends its requests |
| `server` | Beak's defaults | Where the server binds |
| `resources` | `{}` | Per-resource presentation |
| `theme` | see below | How the navigation behaves |

## `api`

```yaml
api:
  baseUrl: http://localhost:8080
```

`baseUrl` becomes a compile-time default the panel reads:

```dart
const String.fromEnvironment(
  'BEAK_API_BASE_URL',
  defaultValue: 'http://localhost:8080',
)
```

So a build can point elsewhere without touching the file:

```bash
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

Set `baseUrl: auto` and the panel calls the origin it was served from, which is
what a single-host deployment wants.

## `server`

```yaml
server:
  port: 8180
  host: 0.0.0.0
```

Both are *defaults*. A real `PORT` or `HOST` in the environment still wins,
because where a process binds is a deployment's decision, not a repository's.
Use this when a project has a fixed development port. Two Beak apps in one
repository cannot both have 8080.

## `resources`

Keyed by **table name**, which is what `@Resource(table:)` says or what Beak
derived from the class name. A key matching no discovered table is an error
naming the line, with a did-you-mean, rather than a setting that silently does
nothing.

| Key | What it decides |
| --- | --- |
| `icon` | The sidebar icon: any `OiIcons` name, in lowerCamelCase |
| `label` | The navigation label (default: the title-cased table name) |
| `section` | The sidebar group this resource is filed under |
| `hidden` | `true` keeps it out of the sidebar |

`hidden` does not remove anything. The model is still registered, still has an
API, and is still reachable as the far side of a relationship. It just does not
earn a sidebar entry, which is what you want for a table like `order_items`,
always reached through the order it belongs to.

An icon that is not a lowerCamelCase identifier fails at `beak prepare` naming
the line. That check exists because the value is spliced into generated code,
and a typo would otherwise be a compile error inside a file you did not write.

## `theme`

The sidebar's two behaviours live here, nested under `theme`:

```yaml
theme:
  sidebar:
    collapsible: true
    startCollapsed: false
```

`collapsible` defaults to `true` and `startCollapsed` to `false`, so a panel
that wants neither can leave the whole block out. Anything else about the look
of the panel is Dart, in `lib/theme.dart`.

## What does not live here

Anything that is a decision about behaviour rather than appearance:

- **A resource's filters, actions, view modes or layouts** live in
  `lib/resources/<table>.dart`, in Dart, where they are type-checked. Run
  `beak eject resource <table>` to start one.
- **Auth, policy and middleware** live in `lib/server.dart`.
- **The theme** lives in `lib/theme.dart`.
- **The dashboard** lives in `lib/dashboard.dart`.

Each of those is a file Beak notices by its path; `beak eject <part>` writes
the starter, which returns Beak's own default so it compiles and changes
nothing until your first edit.

## Continue reading

- [Annotations](annotations.md) the decisions that live on the schema class.
- [CLI commands](cli-commands.md) `prepare`, `eject`, `doctor` and the rest.
- [Project structure](../start-here/project-structure.md) what each folder is for.
