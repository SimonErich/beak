# Superdashboard

Beak at scale: **49 resources**, every one of the 48 block types, a charts gallery, a vector
map, notifications, auth and maintenance screens, an email client, a chat, a
file manager, a kanban board and a calendar. All of it from seeded data, and
none of it from hand-written widgets.

```console
dart run bin/migrate.dart migrate     # create the schema
dart run bin/migrate.dart db:seed     # fill every domain
beak dev                              # API on :8180, panel on :3000
```

The database is a SQLite file created on first run. Set `DATABASE_URL` for
Postgres; `melos run up` brings one up on 25432 alongside MinIO, which the
`e2e`-tagged suite needs.

## What it is for

`examples/store` teaches Beak. This one answers the next question: does it hold
up?

- **49 schema classes** under `lib/models/`, grouped into twelve domains. They
  are 2,394 lines. The generated columns, models, relationships, record views
  and migrations they produce are several times that.
- **17 of the 49 are navigable.** `beak.yaml` says which, under which heading,
  behind which icon, and hides the other 32. A hidden resource keeps its API,
  its model and its relationships; it just does not earn a sidebar entry.
- **17 files under `lib/resources/`**, one per navigable resource, each holding
  only what a person decided: a detail layout, a filter, a kanban view, a form
  wizard.
- **15 screens** under `lib/screens/`, each a block tree, plus
  `lib/dashboard.dart` for the one at `/`.

## Where things are

| What | Where |
| --- | --- |
| The 49 resources | `lib/models/<domain>/<name>.dart` |
| Which are navigable, and how they appear | `beak.yaml` |
| One resource's filters, actions, layouts | `lib/resources/<table>.dart` |
| The screen at `/` | `lib/dashboard.dart` |
| The other 14 screens | `lib/screens/` |
| Notifications, auth, maintenance, the theme mode | `lib/panel.dart` |
| The upload driver registry | `lib/server.dart` |
| Schema and data | `lib/migrations/`, `lib/seeders/` |
| Generated wiring | `lib/beak/*.g.dart`, `lib/models/**/*.beak.dart` |

## Tests

```console
flutter test                       # panel, models, migrations, seeders
melos run up && flutter test test/e2e --tags e2e
```
