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
