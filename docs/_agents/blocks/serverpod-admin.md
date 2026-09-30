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
