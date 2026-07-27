# Beak Store

The flagship example: a coffee shop's admin panel, and the only one that
exercises Beak's whole surface. The tutorial and every Schema/Backend/Panel
page in the docs quote this package.

```console
dart run bin/migrate.dart migrate     # create the tables (SQLite, no setup)
dart run bin/migrate.dart db:seed     # a small, fixed catalog
beak dev                              # API on :8080, panel on :3000
```

Sign in as `ada@example.com` / `espresso` (staff) or `linus@example.com` /
`grinder` (a customer, who sees only their own orders).

## What is hand-written

Everything under `lib/`, except `lib/beak/*.g.dart` and `lib/models/*.beak.dart`
— those are `beak prepare`'s output, committed so a checkout compiles without
running anything.

| File | What it decides |
|---|---|
| `lib/models/*.dart` | the seven schemas: every column kind, all four relationship kinds, soft deletes, timestamps |
| `beak.yaml` | the panel's title, and each resource's icon, section and visibility |
| `lib/server.dart` | who may sign in, and which rows each of them sees |
| `lib/dashboard.dart` | the screen at `/`: four aggregates, a chart, two lists |
| `lib/screens/restock_screen.dart` | a screen the generated pages could not produce |
| `lib/resources/products.dart` | the product show/edit layout, plus one row action and one bulk action |
| `lib/resources/orders.dart` | the order form as a four-step wizard |
| `lib/seeders/store_seeder.dart` | the fixed catalog tests assert against |

Nothing else. There is no registry to maintain, no resource list, no route
table, no API code and no per-model page.

## What it demonstrates

- **All 13 column kinds** and **all four relationship kinds** — `test/widget_test.dart`
  fails if a kind stops being shown here.
- **Uploads** with server-side rules and a generated thumbnail, stored on
  local disk in development and served by the same server.
- **Auth and a row policy**: the catalog is public, orders need an account,
  customers see only their own, and only staff may delete.
- **Soft delete + restore**, optimistic concurrency (a stale save is a 409),
  CSV export, global search, aggregates, and health probes.
- **SQLite and Postgres**, proven by running one suite against both.

## Tests

```console
flutter test                       # panel smoke + the coverage matrices
dart test test/api_sqlite_test.dart  # the whole API, on sqlite::memory:
melos run up && dart test --tags e2e # the same suite, on Postgres
```

`test/api_scenario.dart` holds every API assertion once; the two runners
differ only in the environment they hand it.
