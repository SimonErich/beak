# Testing and shipping

> Test a Beak project at the right level, know what it costs and exposes, configure it, and put the server and panel on a host.

This section covers the stretch between "it runs on my machine" and "it runs for other people": testing at the level that answers your question, reading what a screen costs and what an endpoint exposes, configuring the backend, and putting the server and the panel on a host.

A fresh Beak project needs no infrastructure. It has no `docker-compose.yml`, no `.env` and no credentials, `DATABASE_URL` defaults to a SQLite file, uploads go to a directory beside the project, and the whole loop is `beak migrate` then `beak dev`. Everything in this section is what you add after that, and each piece is opt-in.

## Two programs, two kinds of check

A project is one package that compiles to two programs. The server is pure Dart: the generated API, your policy, your migrations. The panel is Flutter: tables, forms and blocks that render whatever the server returns. They fail differently, so they are tested differently and deployed differently.

| Half | Compiles to | Needs at build time | Checked by |
| --- | --- | --- | --- |
| Server | One executable bundle, plus a migrate bundle | Dart, and a Flutter SDK to resolve the project | API tests on in-memory SQLite, policy tests, `beak doctor` |
| Panel | Static web files | Flutter, obers_ui | Widget tests over an in-memory data source, a real web build |

`beak doctor` enforces the split: it fails when a panel file imports server code. The check exists because `dart:io` compiles for the web and only breaks when it runs.

## Read this before you deploy

`deploy/` in the repository is a reference for the shop, not a platform. As checked for 0.9.0, its panel image cannot build until the obers_ui pin moves. The failure is described at the top of [Going to production](going-to-production.md), next to the server and migrate steps that do work.

The dev stack in the repository's `docker-compose.yml` (Postgres, MinIO, a console) is for working on Beak and for the service-backed test suites, not for deploying. It lives under Contributing: [Dev infrastructure](../contributing/dev-infrastructure.md).

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Test a panel, a form, a save, a policy or a migration at the cheapest level that proves it | [Testing](testing.md) | The in-memory data source, form sessions with no screen, the real API on in-memory SQLite, schema parity |
| Count the requests and statements a screen costs, and find what a slow one is waiting on | [Performance](performance.md) | Measured costs per operation, paging, indexes, dashboards, the single isolate and the pool |
| Close the seams before the API faces the internet | [Security](security.md) | Sessions, deny-by-default policies, row scopes, uploads, CORS, and the gaps that remain |
| Set the variables the backend reads and see which value wins | [Environment and config](environment-and-config.md) | Every variable, the `.env` rules, `WORM_ENV`, and the compiled-in panel origin |
| Build, migrate and run the server and panel on a host | [Going to production](going-to-production.md) | The `deploy/` files, the commands that work, and what stays yours |

## Continue reading

- [Testing](testing.md) the first stop, and the cheapest.
- [Going to production](going-to-production.md) the deployment files and their known problems.
- [Working with obers_ui](../contributing/working-with-obers-ui.md) how the panel's UI library is pinned by commit.
