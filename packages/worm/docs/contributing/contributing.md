---
title: Contributing to worm
description: The monorepo layout, dev setup, test matrix, lint rules, and docs workflow for worm contributors.
---

This page gets you from a fresh clone to a green test matrix and a merged change. Welcome to the flock.

## The monorepo at a glance

Worm lives in the `beak` monorepo. The repo root is a Flutter app shell; all ORM development happens under `packages/`. Seven Dart packages make up the project:

| Package | Role |
| --- | --- |
| `worm` | The ORM core: models, query builder, descriptors, relations, migrations, seeding, validation, the `InMemoryAdapter`, the CLI, and the codegen core. |
| `worm_generator` | The `build_runner` front end. Reads annotations with the analyzer through a `SharedPartBuilder`; `source_gen`'s combining builder merges the output into `.g.dart` part files. |
| `worm_lints` | A `custom_lint` plugin with the repo's own lint rules. |
| `worm_sqlite` | SQLite adapter and SQL compiler (wraps `sqlite3`). |
| `worm_postgres` | PostgreSQL adapter and SQL compiler (wraps `postgres`). |
| `worm_mysql` | MySQL adapter and SQL compiler (wraps `mysql_client_plus`). |
| `worm_mongodb` | MongoDB adapter and filter compiler (wraps `mongo_dart`). |

Every package declares `publish_to: none` and version `0.1.0`: this is a monorepo-internal project, and packages depend on each other by path. All seven require Dart SDK `^3.11.0`.

## Dev setup

You need a Dart SDK at 3.11 or newer. No Flutter tooling is required for the packages.

```sh
git clone <repo-url> beak
cd beak/packages/worm
dart pub get
```

Before you consider any change finished, run the full local gate for the package you touched:

```sh
dart format .
dart analyze
dart test
```

All three must be clean. In `packages/worm` there is a fourth check, the custom lint rules:

```sh
dart run custom_lint
```

## Running the tests

Each package has its own suite; run `dart test` from the package directory.

- `worm` and `worm_sqlite` run entirely offline. The core suite uses `InMemoryAdapter`, and SQLite runs in process on fresh in-memory databases.
- `worm_generator` and `worm_lints` are offline too (analyzer and string-emission tests).
- `worm_postgres`, `worm_mysql`, and `worm_mongodb` each contain a live-database suite gated on an environment variable. When the variable is unset, the suite registers a single skipped placeholder test, so a plain `dart test` still passes everywhere.

| Package | Env var | Example value |
| --- | --- | --- |
| `worm_postgres` | `PG_DB` | `postgres://worm:worm@localhost:5432/worm_test` |
| `worm_mysql` | `MYSQL_URL` | `mysql://worm:worm@127.0.0.1:3310/worm_test` |
| `worm_mongodb` | `MONGO_URI` | `mongodb://localhost:27017/worm_test` |

## Live databases with docker compose

The repo root ships a `docker-compose.yml` with three services for the gated suites: `mysql` (MySQL 8.4, host port **3310**, container port 3306), `postgres` (PostgreSQL 16, port 5432), and `mongo` (MongoDB 7, port 27017). MySQL sits on 3310 because 3306 and 3307 are often taken by other local containers; the compose file also mounts an `init.sql` that switches the `worm` user to `mysql_native_password` so the suite can connect without TLS.

The full live matrix, from the repo root:

```sh
docker compose up -d mysql postgres mongo

PG_DB=postgres://worm:worm@localhost:5432/worm_test \
  dart test --directory packages/worm_postgres

MYSQL_URL=mysql://worm:worm@127.0.0.1:3310/worm_test \
  dart test --directory packages/worm_mysql

MONGO_URI=mongodb://localhost:27017/worm_test \
  dart test --directory packages/worm_mongodb

docker compose down -v
```

All three suites run the shared adapter contract kit plus driver-specific integration tests. The kit is documented in [writing a database driver](./writing-a-database-driver.md).

## Coding conventions

The repo is developed under strict typing rules. The short version:

- Use the most specific type possible. `Object` and `Object?` are last resorts; `dynamic` is forbidden outside unavoidable interop (and then needs a comment).
- No `Map<String, dynamic>` as a domain type. Use typed classes.
- No `as` casts. Use pattern matching or typed APIs. Generated code contains zero `as` casts, and tests enforce that.
- Throw typed exceptions from the `WormException` hierarchy, never bare `Exception`.
- No internal ticket references (`WI-123`, `AC-4`) in comments. Enforced by `worm_lints` (see below).
- Prefer `const` constructors, short single-purpose functions, and tests that verify behavior rather than existence.

### Golden snapshots

Descriptors are worm's compiler-facing contract, so their serialized shape is frozen with golden tests. `packages/worm/test/goldens/` holds 13 descriptor snapshots plus a `qb/` set for the fluent query builder. The helper compares `descriptor.toMap()` as indented JSON against the `.golden` file, creates missing files on first run, and regenerates everything when you set `UPDATE_GOLDENS=true`:

```sh
UPDATE_GOLDENS=true dart test test/src/query/descriptor/golden_snapshot_test.dart
```

Run golden tests from the package directory. The golden path is resolved relative to the working directory, so running from anywhere else scatters stray `test/goldens/` folders.

## worm_lints

`worm_lints` is a `custom_lint` plugin. Its entry point, `createPlugin()` in `lib/worm_lints.dart`, returns a `PluginBase` that registers every shipped rule. There is currently one:

| Rule | Severity | What it flags |
| --- | --- | --- |
| `no_ticket_reference` | WARNING | Any comment matching `WI-<digits>` or `AC-<digits>` (regex `WI-\d+\|AC-\d+`). Message: "Comments must not contain internal ticket references (WI-XXX / AC-N)." The correction asks you to rewrite the comment with intent-focused language and track tickets in commits, PRs, or the issue tracker. |

The rule exposes `static RegExp pattern` and `static bool matches(String)` so unit tests can exercise the classification logic without spinning up the analyzer.

Wiring in a consumer package looks like what `packages/worm` does:

```yaml title="pubspec.yaml"
dev_dependencies:
  custom_lint: 0.8.1
  worm_lints:
    path: ../worm_lints
```

```yaml title="analysis_options.yaml"
analyzer:
  plugins:
    - custom_lint
```

Then run `dart run custom_lint`. Note the exact version pin: `worm_lints` pins `custom_lint_builder` and `custom_lint_core` to `0.8.1`, so consumers must pin `custom_lint: 0.8.1` to match.

To add a rule: create a `DartLintRule` subclass under `lib/src/`, register it in `createPlugin()`, export it from the barrel, and give its matching logic static helpers so it stays testable without the analyzer.

## How the docs site builds

The documentation you are reading is plain markdown in `packages/worm/docs/`. A separate Astro Starlight project in `packages/worm/docs_site/` renders it:

- A glob content loader points at `../docs` and picks up every `.md`/`.mdx` file. Files and directories starting with `_` are excluded, so `_assets/` style folders stay unpublished.
- ` ```mermaid ` fences render as diagrams via `astro-mermaid`.
- The `starlight-llms-txt` plugin exports the whole site as `llms.txt` for AI agents.
- A link checker validates every relative link before each build, and CI (`.github/workflows/docs.yml`) builds the site on every pull request that touches `docs/` or `docs_site/`, deploying to GitHub Pages from `main`.

Local preview:

```sh
cd packages/worm/docs_site
npm install
npm run dev
```

### Adding a page

1. Create a kebab-case `.md` file in the right section directory, for example `docs/guides/my-topic.md`.
2. Frontmatter is `title` and `description` only. Do not repeat the title as a `#` heading; start with a one-or-two sentence intro.
3. Link to other pages with relative paths including the extension: `[transactions](../database/transactions.md)`.
4. Verify every identifier and code sample against `lib/` source. The code wins over any older doc.
5. Add the page to the `sidebar` array in `docs_site/astro.config.mjs`. The sidebar is curated by hand, so a page you skip here still builds and stays reachable by URL and search, but it will not appear in the navigation until you list it.

## Continue reading

- [Architecture](./architecture.md) explains the descriptor-first design your change will live inside.
- [Writing a database driver](./writing-a-database-driver.md) is the deep contributor guide, including the shared contract test kit.
- [Code generation](../models/code-generation.md) covers the `worm_generator` pipeline from annotations to `.g.dart`.
- [Testing](../guides/testing.md) shows the user-facing testing utilities you'll rely on in your own tests.
