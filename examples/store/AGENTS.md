# Store — notes for coding agents

This is a [Beak](https://github.com/SimonErich/beak) admin panel. Beak is
configuration-driven: you declare models and screens, and it generates the
API, the router, the tables, the forms and the detail views.

## Where things go

| What | Where |
| --- | --- |
| A resource | `lib/models/<name>.dart` — one `@Resource` class per file |
| A custom page | `lib/screens/<name>.dart` — a top-level `BeakScreen` |
| Panel title, icons, sections | `beak.yaml` |
| Theme / auth / dashboard / server overrides | `lib/{theme,auth,dashboard,server}.dart` |
| Generated wiring | `lib/beak/*.g.dart` — do not edit |

Nothing needs registering. `beak prepare` reads each schema class and
generates its columns, model, relationships (both sides) and a typed record
view into a `.beak.dart` part beside it, then wires everything up.

A field's Dart type picks its column: `String`, `BeakText`, `BeakRichText`,
`int`, `double`, `bool`, `DateTime`, an enum, `BeakHexColor`, `BeakImageRef`,
`BeakFileRef`. Nullability decides whether it is required.

## Invariants

- Never write a column key or table name as a string. Reference the column
  constant (`NoteColumns.title`) and the model (`const NoteModel().query()`).
- Never import `package:flutter/material.dart` or `cupertino.dart`. Beak's UI
  is obers_ui.
- Widgets are `HookWidget`; `StatefulWidget` is not used.
- Read record values through the generated record view: `record.asNote.title`
  is a `String`, `record.asNote.body` a `String?` — matching what the schema
  declared. `NoteColumns.title.readFrom(record)` is the lower-level form.

## Commands

```bash
beak dev        # generate, serve the API, run the panel
beak prepare    # regenerate the wiring only
beak migrate    # apply migrations
beak seed       # run seeders
beak doctor     # diagnose the project
```
