# Quickstart

A [Beak](https://github.com/SimonErich/beak) admin panel: declare a resource,
get its API, its table, its form and its detail page.

```console
beak dev                       # API on :8080, panel on :3000
```

The database is a SQLite file beside this README, created on first run — set
`DATABASE_URL` when you want Postgres instead.

## Adding a resource

```console
beak make:resource Product --fields name:string!,price:decimal!
```

That writes `lib/models/product.dart` and runs `beak prepare`, which generates
the columns, the model, both sides of every relationship, a typed record view
and the migration. Apply it with:

```console
dart run bin/migrate.dart migrate
```

## Where things go

| What | Where |
| --- | --- |
| A resource | `lib/models/<name>.dart` |
| A custom page | `lib/screens/<name>.dart` |
| Panel title, icons, sections | `beak.yaml` |
| Theme, auth, dashboard, server | `lib/{theme,auth,dashboard,server}.dart` — `beak eject <part>` writes the starter |
| One resource's panel config | `lib/resources/<table>.dart` — `beak eject resource <table>` |
| Generated wiring | `lib/beak/*.g.dart`, `lib/models/*.beak.dart` — committed, never edited |

`beak doctor` checks the project; `beak prepare` regenerates after any change.
