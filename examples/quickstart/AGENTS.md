# Quickstart: notes for coding agents

This is a [Beak](https://github.com/SimonErich/beak) admin panel. Beak is
configuration-driven: you declare schema classes and resources, and it
generates the API, the router, the tables, the forms and the detail pages.

## Where things go

| What | Where |
| --- | --- |
| A resource's schema | `lib/resources/<plural>/models/<name>.dart`: one `@Resource` class per file |
| How the panel presents it | `lib/resources/<plural>/<name>_resource.dart`: a `BeakResource` subclass |
| A custom page | `lib/screens/<name>.dart`: a top-level `BeakScreen` |
| Panel title and API origin | `beak.yaml` |
| Theme / auth / server overrides | `lib/{theme,auth,server}.dart` |
| Generated wiring | `lib/beak/*.g.dart`, `*.beak.dart`: do not edit |

`beak prepare` reads each schema class and generates its columns, model,
relationships (both sides) and a typed record view into a `.beak.dart` part
beside it, then wires everything up.

`lib/main.dart` is generated too. It boots the panel Beak builds from every
model, using a `BeakResource` subclass for a model where the project has one,
so nothing needs registering. `beak eject main` turns it into an authored
`BeakPanel(resources: [...])` that `beak prepare` leaves alone.

A field's Dart type picks its column: `String`, `BeakText`, `BeakRichText`,
`int`, `double`, `bool`, `DateTime`, an enum, `BeakHexColor`, `BeakImageRef`,
`BeakFileRef`. Nullability decides whether it is required. Bounds are rules:
`@Column(rules: [BeakMaxLength(120)])` validates the value and sizes the
stored column.

## Invariants

- Never write a column key or table name as a string. Reference a field
  through the generated model (`NoteModel.title`) and query through the model
  (`const NoteModel().query()`).
- Never import `package:flutter/material.dart` or `cupertino.dart`. Beak's UI
  is obers_ui.
- Widgets are `HookWidget`; `StatefulWidget` is not used.
- Read record values through the generated record view: `record.asNote.title`
  is a `String`, `record.asNote.body` a `String?`, matching what the schema
  declared. `NoteModel.title.readFrom(record)` is the lower-level form.

## Commands

```bash
beak migrate            # apply migrations (run it before the first beak dev)
beak dev                # regenerate, serve the API, print the flutter run line
flutter run -d chrome   # the panel, in a second terminal
beak prepare            # regenerate the wiring only
beak make:resource Product --fields name:string!   # a schema and its resource class
beak seed               # run seeders
beak doctor             # diagnose the project
```
