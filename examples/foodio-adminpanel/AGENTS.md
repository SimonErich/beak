# Foodio Adminpanel

<!-- BEGIN:beak-agent-rules -->
## Beak

This is a Beak 0.9.0 admin panel, and Beak moves faster than your
training data. Read `.dart_tool/beak/docs/ai-index.md` before writing Beak code: it routes each
task to the page that covers it and lists the APIs you probably remember
wrong. Folder missing? Run `beak docs`.

- Schemas live in `lib/models/*.dart`. After editing one, run `beak prepare`.
  Never edit `*.beak.dart` or `lib/beak/*.g.dart`.
- `lib/main.dart` registers each `BeakResource` in
  `BeakPanel(resources: [...])`.
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

## This project

<!-- Your conventions: domain words, who uses the panel, what "done" means here.
Beak only edits between the markers above. -->
