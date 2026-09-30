# Quickstart

A [Beak](https://github.com/SimonErich/beak) admin panel: declare a resource,
get its API, its table, its form and its detail page.

## Run it

```console
beak migrate    # create the tables, in a SQLite file beside this README
beak dev        # regenerate the wiring, then serve the API on :8080
```

`beak dev` prints the `flutter run -d chrome` line that starts the panel; run
it in a second terminal. Set `DATABASE_URL` when you want Postgres instead of
the SQLite file.

## Adding a resource

```console
beak make:resource Product --fields name:string!,price:decimal!
beak migrate
```

`make:resource` writes the schema class
`lib/resources/products/models/product.dart` and its resource class
`lib/resources/products/product_resource.dart`, then runs `beak prepare`,
which generates the columns, the model, both sides of every relationship, a
typed record view and the create-table migration. `beak migrate` applies it.

## Where things go

| What | Where |
| --- | --- |
| A resource's schema | `lib/resources/<plural>/models/<name>.dart` |
| How the panel presents it | `lib/resources/<plural>/<name>_resource.dart`, a `BeakResource` subclass |
| A custom page | `lib/screens/<name>.dart`, a top-level `BeakScreen` |
| Panel title and API origin | `beak.yaml` |
| Theme, auth, server | `lib/{theme,auth,server}.dart`: `beak eject <part>` writes the starter |
| Generated wiring | `lib/beak/*.g.dart`, `*.beak.dart`: committed, never edited |

## The entrypoint

`lib/main.dart` boots the panel Beak generates from every model: each one
gets a default resource, presented as `beak.yaml` says, and a `BeakResource`
class you write replaces the default for its model. `beak prepare` rewrites
the file, so it is git-ignored.

Run `beak eject main` to compose the panel yourself instead. It rewrites
`lib/main.dart` as a `BeakPanel(resources: [...])` you own and commit, and
`beak prepare` leaves it alone from then on.

`beak doctor` checks the project; `beak prepare` regenerates after any change.
