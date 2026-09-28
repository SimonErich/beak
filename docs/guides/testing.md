---
title: Testing
description: Test declarative configuration, custom widgets and authoritative workflows at their actual boundaries.
---

# Testing

Test observable behavior at the layer responsible for it. A form test proves
binding, validation, suggestions and local drafts; a real API test proves policies,
transactions, database constraints, actions and receipts. Both should use the same
authored models and layouts as the application.

## Local forms and custom widgets

`InMemoryBeakDataSource` implements actual query filtering and relationship
semantics for tests. `BeakRecordingDataSource` wraps another source and records
its calls, so a test can verify that previewing a nested editor performs no writes
or that a dashboard submits the intended aggregate.

The canonical shop provides examples in:

- `test/invoice_form_test.dart`: mixed lines, discounts, tax preview, shared rules
  and immutable historical display.
- `test/custom_shop_test.dart`: variant preview and staging, scoped formatting,
  automatic mutation refresh, explicit errors and retry.
- `test/shop_widget_test.dart`: real resource layouts, narrow/wide rendering and
  values retained while switching tabs.

Inject the source with `BeakPanel(dataSource: ...)` or directly into
`BeakConfiguredForm`. Use the actual schema registry and actual layout functions.
Do not replace rules with test-only versions to make a form pass.

## Authoritative workflows

Plain in-memory CRUD cannot promise server transactions. Model behavior and named
actions require an authoritative commit provider. The shop's order form test uses
`test/support/shop_test_api.dart`: a fresh in-memory SQLite database, the generated
host, migrations, seed and a real HTTP client. It then drives the actual form
session through that client and asserts persisted order and child records.

`test/shop_api_test.dart` tests graph rollback, create-and-issue, payment/cancellation
states, duplicate save identities, snapshot immutability, dependent relationships,
search and duplicate variants. `test/shop_migration_test.dart` verifies an upgrade
preserves legacy records. `test/shop_totals_test.dart` covers the pure rounding and
discount arithmetic without UI or transport.

## Run the example checks

```sh
cd examples/clean_beak_config
flutter test --concurrency=1 test/order_form_test.dart test/invoice_form_test.dart \
  test/fulfillment_form_test.dart test/shop_resource_test.dart \
  test/shop_widget_test.dart test/custom_shop_test.dart
dart test --concurrency=1 test/shop_api_test.dart test/shop_migration_test.dart \
  test/shop_totals_test.dart
flutter analyze
```

Framework packages have their own transport, policy, rendering and integration
suites. Service-backed PostgreSQL or storage tests are separate from the local
SQLite example; run the corresponding configured gate when changing those adapters.

## Failures worth exercising

Include invalid and unavailable relationship selections, a field hidden by
presentation but required by the server, removed owned rows, rollback after a child
fails, duplicate named actions, unknown outcomes followed by recovery, stale draft
restoration, and rejected writes with field errors. Verify that a read-only or
pending surface cannot silently mutate its draft.

Use the repository's coverage gates without excluding new logic to meet a number.
Core's strict coverage requirement supports focused boundary tests; copied tests
that only mirror implementation are not a substitute for realistic workflows.

## Continue reading

- [Writing tests](../contributing/writing-tests.md).
- [Results and errors](../concepts/results-and-errors.md).
