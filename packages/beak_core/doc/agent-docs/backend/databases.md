# Databases

> Run on a SQLite file by default, point DATABASE_URL at Postgres when you need a server, and know what Beak does with the connection.

A new Beak project runs on a SQLite file and needs no `.env`. After this page you can say which database a given `DATABASE_URL` opens, move a project to Postgres, and predict which parts of the connection you cannot tune.

Beak starts on a file because requiring a database to see anything at all loses more first-time users than any other step. The schema classes, the migrations and the API are the same on both databases, so the choice is one line in `.env`.

## At a glance

`beakHost()` reads `DATABASE_URL` from the environment and `adapterFromUrl` turns it into a worm adapter. That is the only place a URL scheme becomes a driver, so `beak dev`, `beak migrate` and a hand-built server cannot disagree about it.

| `DATABASE_URL` | Opens | Good for |
| --- | --- | --- |
| unset | `sqlite:beak.db`, a file beside the process | The first hour, demos, one server on one disk |
| `sqlite:beak.db`, `sqlite:///var/data/beak.db`, `file:beak.db` | SQLite at that path | The same, with the file where you want it |
| `sqlite::memory:` | SQLite that vanishes with the process | Tests. The server migrates and seeds it itself on boot |
| `postgres://user:pass@host:5432/db`, `postgresql://...` | Postgres, port `5432` unless the URL names one | A second server process, a managed database, backups you do not run yourself |
| `postgres://...?sslmode=require` | Postgres over TLS | Anything that crosses a network you do not own |

Any other scheme is a boot error. [Environment and config](../shipping/environment-and-config.md) lists the rest of the variables and how `.env` and the process environment combine.

## SQLite, the default

The file is created on first use, in the working directory of the process. `beak create` lists the database files in `.gitignore`, so they never reach a commit.

Beak opens it with three settings: write-ahead logging (`journal_mode = WAL`), foreign keys enforced, and `synchronous = NORMAL`. WAL is why `beak.db-wal` and `beak.db-shm` appear beside `beak.db`. The three files are one database. Copying `beak.db` alone while the server runs can miss the newest writes, so back up with `sqlite3 beak.db ".backup copy.db"` or copy all three with the server stopped.

SQLite runs on one connection. That is plenty for an admin panel, and one server process per file is the setup Beak's tests and examples use. A second process would have its own session store and its own outbox worker, see [Auth and policies](auth-and-policies.md) and [Durable effects](durable-effects.md). When a second process is the plan, use Postgres from the start.

`sqlite::memory:` deserves its own sentence. Nothing else can prepare a database that lives inside one process, so `BeakServeHost.serve()` applies the migrations and runs the seeders itself before it listens. It is the only database Beak migrates on boot.

## Postgres

Put the URL in `.env`, which the scaffold already git-ignores, and run the same commands as before:

```bash
docker run -d --name beak-pg -p 5432:5432 \
  -e POSTGRES_USER=beak -e POSTGRES_PASSWORD=beak -e POSTGRES_DB=beak postgres:16-alpine
echo 'DATABASE_URL=postgres://beak:beak@localhost:5432/beak' >> .env
beak migrate
beak seed
beak dev
```

```console
$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_162002_create_products_table
$ beak seed
seeded  ProductSeeder
```

Use the container only as a scratch database. It has no volume, so `docker rm` takes the data with it.

The URL carries the credentials, and `BeakBackendConfig.toString` prints the URL without them, so logging the config is safe. Percent-encode a password that contains `@`, `:` or `/`.

### What Beak does with the connection

| Setting | Value | Can you change it? |
| --- | --- | --- |
| Pool size | 10 connections | No variable. `adapterFromUrl(url, poolSize: n)` takes one if you build the adapter yourself |
| Connecting | Lazy: the pool opens on first use | A wrong password or an unreachable host appears at the first query, which is usually `beak migrate` |
| TLS | On for `?sslmode=require`, off for anything else | `sslmode=require` is the only value read. `verify-full` leaves TLS off, so check certificates at the network layer |
| Schema | `public` | Not configurable |
| Port | `5432` when the URL has none | Name it in the URL |

### What the same model becomes

The migrations read the model, so one schema class produces a table on either database. This is the `products` table from the two runs above:

| Column | Postgres | SQLite |
| --- | --- | --- |
| `id` | `uuid` | `TEXT` |
| `name` (required string) | `character varying(255) not null` | `TEXT NOT NULL` |
| `price` (decimal) | `numeric(10,2) not null` | `NUMERIC NOT NULL` |
| `active` (bool) | `boolean` | `INTEGER` |
| `created_at`, `updated_at` | `timestamp with time zone` | `TEXT` (ISO-8601) |

Exact money and other semantic fields store scaled integers on both, see [Semantic fields](../models/semantic-fields.md), so a total does not drift when you change databases.

Beak does not move data between databases. Switching a project that already has records means creating the Postgres schema with `beak migrate`, then loading the rows with your own tooling. A seeder covers demo data, not a copy.

## Other worm drivers

The repository vendors `worm_mysql` and `worm_mongodb` next to the two that Beak wires up. `DATABASE_URL` does not select them. A `mysql://` URL fails with `DATABASE_URL must use the postgres:// scheme, got "mysql"`, because every URL that is not SQLite is read as Postgres.

`BeakServeHost.buildServer(adapter:)` accepts any worm `DatabaseAdapter`, so a hand-written entrypoint could hand it another one. Beak's tests run against SQLite and Postgres, and nothing here has verified graph commits, the outbox or the migrations on the others. The graph-commit hooks refuse an adapter without transactions, see [Graph commits](../architecture/graph-commits.md).

If your backend is a Serverpod server, none of this page applies: Serverpod owns the database. See [Serverpod](../serverpod/index.md).

## An existing database

`beak introspect <database-url>` reads the tables that already exist and writes schema classes for them, plus a baseline migration that records those tables as Beak's without changing them. Then `beak migrate` moves the database forward like any other. The command, its flags and what it decides for you are in [CLI commands](../reference/cli-commands.md#beak-introspect), and the walkthrough is [An existing database](../start-here/paths/existing-database.md).

## Rules and limits

| Rule | Consequence |
| --- | --- |
| A bad `DATABASE_URL` fails the boot | `BeakConfigurationException` with the variable named. `beak migrate` and the generated `bin/serve.dart` print it as one line (`error: DATABASE_URL must ...`) and exit `78`, where a hand-written entry point that calls `BeakServeHost.serve()` and does not catch it ends in `Unhandled exception:` and exit `255` |
| `beak.db` without a scheme is not a URL | `DATABASE_URL must be an absolute URL, got "beak.db"`. Write `sqlite:beak.db` |
| Only `sqlite:`, `file:` and `postgres(ql)://` are understood | Every other scheme is read as Postgres and refused |
| Postgres connects on first use | The boot succeeds against a dead database. `/healthz` answers `200`, `/readyz` answers `503` and the connection error goes to stderr |
| The pool has ten connections and SQLite has one | Neither is configurable through the environment |
| `beak doctor`, `beak make:migration --from-drift`, `beak migrate` and the server all resolve `DATABASE_URL` the same way | The process environment wins over `.env`, as everywhere else. A URL set in the shell or in CI is the one doctor inspects |
| Migrations are never applied on boot, except for `sqlite::memory:` | Run `beak migrate` before the server that needs the columns starts |

## Verify it

`beak migrate status` opens the database the server would open, so it proves the URL, the credentials and the schema in one command:

```console
$ beak migrate status
Migration                             | Batch | Status
------------------------------------------------------
[x] 20260926_000000_beak_commit_receipts  | 1     | applied
[x] 20260927_000000_beak_outbox           | 1     | applied
[x] 20260929_162002_create_products_table | 1     | applied
```

With the server running, `/readyz` proves the same from the outside:

```console
$ curl -s localhost:8080/readyz
{"status":"ok"}
```

A wrong password is not a `readyz` question, it is a first-query question. The failure looks like this, and it names the user but never the password:

```console
$ DATABASE_URL=postgres://beak:wrong@localhost:5432/beak beak migrate
error: password authentication failed for user "beak"
```

## Reference

- `packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart`: `adapterFromUrl`, `initializeBeakDatabase`, the Postgres URL parser.
- `packages/beak_backend/lib/src/config/beak_backend_config.dart`: `BeakBackendConfig`, `isSqliteUrl`, `sqliteFilePathOf`.
- `packages/beak_backend/lib/src/data/worm/beak_blueprint.dart`: the column mapping a migration uses.
- [Configuration and environment](../reference/configuration.md#the-server) has the variables and the `BeakBackendConfig` members.

## Continue reading

- [Migrations](migrations.md) how the schema gets onto whichever database you picked.
- [Seeding](seeding.md) demo data that is safe to load twice.
- [Going to production](../shipping/going-to-production.md) the database as one part of a deployment.
- [Performance](../shipping/performance.md) the pool, the single SQLite connection and what they cost under load.
