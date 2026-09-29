# Seeding and the API

> Run the maintained shop against its generated server and SQLite database.

The shop includes migrations and a repeatable seeder. From the repository root:

```bash
cd examples/clean_beak_config
flutter pub get
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

Start the panel in another terminal:

```bash
cd examples/clean_beak_config
flutter run -d chrome --web-port=3000
```

The local database is `beak.db`. Existing migrations remain part of its upgrade history. The seed preserves existing records. Change the API origin with `BEAK_API_BASE_URL` when building the panel for another host.

## Shared operations

The generated server mounts query, aggregate, validation, CRUD, relationship, upload and graph-commit endpoints. Configured forms submit graphs automatically. Model behavior and graph preparers run against trusted metadata; browser-supplied calculated values are never authoritative.

The invoice example exercises several records in one transaction: lines, vouchers, customer snapshots and totals. A failed rule rolls back the graph. Retrying a successful save identity returns its receipt.

## Test the server

```bash
dart test test/shop_api_test.dart test/shop_totals_test.dart test/shop_migration_test.dart
```

These tests exercise real SQLite persistence and business behavior, independently of Flutter widgets.

## Continue reading

- [Shaping the panel](05-shaping-the-panel.md)
- [Running the server](../backend/running-the-server.md)
