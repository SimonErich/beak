# beak_superdashboard

A single-package Beak demo that reproduces a full admin dashboard theme —
dashboard, apps (email, chat, calendar, file manager, invoices, kanban),
content pages (profile, pricing, FAQ), auth/utility pages, forms, tables, a
charts gallery, media gallery/carousel, typography, icons, and a UI-elements
showcase — **entirely from seeded data**, using only declarative Beak-style
widgets (no hand-written custom widgets).

Everything lives in one package:

- `lib/models/` — the shared `BeakModel` definitions (one file per model).
- `lib/migrations/` — worm migrations, grouped by domain.
- `lib/seeders/` — meaningful, coherent seeders (deterministic anchors + faker
  volume).
- `lib/server/` + `bin/server.dart` — the Shelf backend (auto CRUD/relations/
  uploads/search/export/auth over every model).
- `lib/panel/`, `lib/screens/`, `lib/services/` — the Flutter panel: resources,
  custom pages, dashboard, app-module screens, and action services.
- `bin/worm.dart` — the migrate / seed CLI.

## Running

```bash
melos run up                                 # Postgres + MinIO
dart run bin/worm.dart migrate               # create the schema
dart run bin/worm.dart db:seed               # seed all domains
dart run bin/server.dart                     # start the backend on :8180
flutter run                                  # start the panel
```
