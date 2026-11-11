<!-- BEGIN:beak-agent-rules -->
## Beak admin over Serverpod

This package is a Beak {{version}} admin panel for the `{{serverPkg}}`
Serverpod server, and Beak moves faster than your training data. Read
`{{docsIndex}}` (section "Serverpod") before writing Beak code. Folder
missing? Run `beak docs`.

- Serverpod owns the database, auth and migrations; Beak never opens a
  database. Beak's API runs inside `{{serverPkg}}` behind one gated endpoint,
  and this app reaches it through `{{clientPkg}}`.
- Each exposed Serverpod model has a definition class in `{{schemaPkg}}`;
  its field list is the allowlist. After a model change: edit the
  `.spy.yaml`, run `serverpod generate` in `{{serverPkg}}`, update the class,
  then run `beak generate` here.
- The panel is configuration only: screens use `BeakResource.standard` and
  Beak's standard screens, never a custom write path. Custom writes and
  commands are methods of the generated handler bases, implemented in
  `{{serverPkg}}` with its use cases.
- Reference fields through the generated model (`OrderModel.status`), never
  a string. UI is obers_ui; never import `package:flutter/material.dart` or
  `cupertino.dart`. Widgets are `HookWidget`.
- Never edit generated files: `{{schemaPkg}}/lib/src/generated/`,
  `*.beak.dart`, `{{clientPkg}}` and `*.g.dart`.
- Never start the server yourself; `serverpod start` is interactive. Ask the
  user to run it when you need it.
- Hiding a control only hides UI. The server endpoint enforces who may read
  and write what.
- Done means `flutter analyze` and `flutter test` pass here, and
  `dart analyze` passes in `{{serverPkg}}`.

Workflow skills: {{skills}}.
<!-- END:beak-agent-rules -->
