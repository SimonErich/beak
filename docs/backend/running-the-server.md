---
title: Running the server
description: Run the generated Shelf host, configure it, and test the same API in isolation.
---

# Running the server

`beak prepare` discovers schemas, migrations, seeders and the optional
`lib/server.dart` override. It generates `lib/beak/server.g.dart` plus the
`bin/serve.dart` and `bin/migrate.dart` entrypoints. Authored entrypoints are
preserved.

From the canonical shop:

```sh
cd examples/clean_beak_config
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

The default local API listens on port 8080. `DATABASE_URL`, `HOST` and `PORT`
configure the database and socket. The default SQLite file is suitable for local
development; a deployment should choose its persistent database explicitly.
See [environment and configuration](../deployment/environment-and-config.md).

## Customize the generated host

A top-level `BeakServer beakServer(BeakServerDefaults defaults)` in
`lib/server.dart` receives the resolved registry, source, environment and storage
configuration. Return `defaults.build(...)` with the policies or graph preparation
the application needs. Generation connects this function automatically.

The shop's override registers `ShopGraphPreparer.prepare` and lists tables whose
mutations must use the graph endpoint. This makes invoice totals and owned-child
rules transactional and prevents direct CRUD from bypassing that policy. See the
actual `examples/clean_beak_config/lib/server.dart` and
[graph business rules](graph-business-rules.md).

Authentication is optional and must be configured for an authenticated deployment.
The canonical shop deliberately runs without login; it is not an authorization
example. See [auth and policies](auth-and-policies.md).

## Embed or test the handler

`BeakServeHost.buildServer` builds the server without binding a port. The resulting
`BeakServer.handler` is a Shelf handler and can be mounted in another Shelf
application. `start()` binds it when a standalone HTTP server is needed.

The shop's `test/support/shop_test_api.dart` demonstrates a real isolated host:
create an in-memory SQLite adapter, run the host's migrations and seeders, build
and start its server on an ephemeral loopback port, then use `BeakClient`.
Dispose the client, server, adapter and Worm state at the end of the test.

Production and tests therefore use the same registry, policies, action lifecycle
and transport contracts. A custom widget does not need its own endpoints.

## Storage and health

The generated host resolves the configured upload driver. With no explicit driver,
local disk storage is available; `BEAK_STORAGE_DRIVER=none` disables uploads.
Private media requires a private or signed driver; local static files are public.
See [uploads and storage wiring](uploads-and-storage-wiring.md).

Use `/healthz` for process liveness and `/readyz` for readiness. Run migrations as
a deliberate deployment step before starting instances that need the new schema.

## Continue reading

- [Migrations](migrations.md).
- [Auth and policies](auth-and-policies.md).
