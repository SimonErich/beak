// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: docs/_agents/blocks/*.md. Regenerate: melos run agent-docs.

/// The block templates compiled into the CLI.
///
/// `beak agents` renders the templates that ship in the project's
/// docs bundle, so its rules match the Beak version the project
/// resolved. These are what it renders when there is no bundle
/// yet, and each is byte-equal to its file in the repository.
library;

/// The `embedded` block template.
const String beakEmbeddedBlockTemplate = r'''
<!-- BEGIN:beak-agent-rules -->
## Beak

This app contains a Beak {{version}} admin panel next to its own code, and
Beak moves faster than your training data. The rules below apply to Beak files
only: `@Resource` schema classes, `*_resource.dart`, and files importing
`package:beak/`. The rest of the app keeps its own conventions. Read
`{{docsIndex}}` before writing Beak code. Folder missing? Run `beak docs`.

- Panel entrypoint: `{{panelEntry}}`. Run it with
  `flutter run -t {{panelEntry}}`; it registers each `BeakResource` in
  `BeakPanel(resources: [...])`.
- Schemas live in `{{schemaGlob}}`. After editing one, run `beak prepare`.
  Never edit `*.beak.dart` or `lib/beak/*.g.dart`.
- Reference fields through the generated model (`ProductModel.name`), never a
  string. No `dynamic`, no `as` casts.
- Beak files never import `package:flutter/material.dart` or `cupertino.dart`,
  even where the app does. Widgets are `HookWidget`.
- Business rules go on the schema (`behavior`, `validationRules`), never in a
  widget callback. The server re-runs them on every save.
- Never edit a migration that already ran. Change a shipped table with
  `beak make:migration <Name> --from-drift`, review it, then `beak migrate`.
- `beak dev` serves the API only. Run the panel yourself in a second terminal.
- Done means `beak doctor`, `dart format .`, `flutter analyze` and
  `flutter test` are all clean.

Workflow skills: {{skills}}.
<!-- END:beak-agent-rules -->
''';

/// The `serverpod-admin` block template.
const String beakServerpodAdminBlockTemplate = r'''
<!-- BEGIN:beak-agent-rules -->
## Beak admin over Serverpod

This package is a Beak {{version}} admin panel for the `{{serverPkg}}`
Serverpod server, and Beak moves faster than your training data. Read
`{{docsIndex}}` (section "Serverpod") before writing Beak code. Folder
missing? Run `beak docs`.

- Serverpod owns the database, auth and migrations; Beak never opens a
  database. Beak's API runs inside `{{serverPkg}}` behind one gated endpoint,
  and this app reaches it through `{{clientPkg}}`.
- Each table the panel shows is mirrored as a Beak schema class in
  `{{schemaPkg}}`. After a model change: edit the `.spy.yaml`, run
  `serverpod generate` in `{{serverPkg}}`, update the matching schema class,
  then run `beak prepare` in `{{schemaPkg}}`.
- Never edit generated files: `lib/src/generated/` in the server,
  `{{clientPkg}}`, `*.beak.dart` and `*.g.dart`.
- Never start the server yourself; `serverpod start` is interactive. Ask the
  user to run it when you need it.
- Resources are `lib/resources/*_resource.dart`, registered in
  `BeakPanel(resources: [...])`. Reference fields through the generated model
  (`OrderModel.status`), never a string. UI is obers_ui; never import
  `package:flutter/material.dart` or `cupertino.dart`. Widgets are
  `HookWidget`.
- Hiding a control only hides UI. The server endpoint enforces who may read
  and write what.
- Done means `flutter analyze` and `flutter test` pass here, and
  `dart analyze` passes in `{{serverPkg}}`.

Workflow skills: {{skills}}.
<!-- END:beak-agent-rules -->
''';

/// The `standalone` block template.
const String beakStandaloneBlockTemplate = r'''
<!-- BEGIN:beak-agent-rules -->
## Beak

This is a Beak {{version}} admin panel, and Beak moves faster than your
training data. Read `{{docsIndex}}` before writing Beak code: it routes each
task to the page that covers it and lists the APIs you probably remember
wrong. Folder missing? Run `beak docs`.

- Schemas live in `{{schemaGlob}}`. After editing one, run `beak prepare`.
  Never edit `*.beak.dart` or `lib/beak/*.g.dart`.
{{#mainIsGenerated}}
- `lib/main.dart` is generated. Panel presentation lives in `beak.yaml`;
  `beak eject main` hands the entrypoint over to you.
{{/mainIsGenerated}}
{{^mainIsGenerated}}
- `{{panelEntry}}` registers each `BeakResource` in
  `BeakPanel(resources: [...])`.
{{/mainIsGenerated}}
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

Workflow skills: {{skills}}.
<!-- END:beak-agent-rules -->
''';

/// The `workspace-root` block template.
const String beakWorkspaceRootBlockTemplate = r'''
<!-- BEGIN:beak-agent-rules -->
## Admin panel (Beak)

`{{adminDir}}/` is a Beak {{version}} admin panel. Before changing it, read
`{{adminDir}}/AGENTS.md`, and run `beak` commands from that directory.
{{#serverpod}}
Data the admin shows starts in `{{serverPkg}}` (a `.spy.yaml` model, then
`serverpod generate`), followed by the matching Beak schema class in
`{{schemaPkg}}`. The rules above about MCP tools, migrations and never
starting the server apply to the admin too.
{{/serverpod}}
<!-- END:beak-agent-rules -->
''';
