---
title: Testing
description: Test a Beak project at three levels, the panel over an in-memory data source, form logic with no screen, and the real API on in-memory SQLite.
type: guide
audience: [beginner, expert]
status: stable
---

# Testing

After this page you can pick the cheapest test that answers your question about a Beak project: a panel over an in-memory data source, a form session with no screen at all, or the generated server running on an in-memory SQLite database. Every level has a helper in `package:beak/testing.dart` or an example to copy.

A Beak project has two halves and they need different tests. The panel is Flutter and renders whatever its data source hands it. The server holds the parts you cannot leave to a client: policies, transactions, model behavior, database constraints. A widget test proves the first half, an API test proves the second, and neither one stands in for the other. A bird that only inspects its own beak has not tested the worm.

## At a glance

| You are testing | Use | Look at |
| --- | --- | --- |
| That the panel boots and renders your resources | `testWidgets` with `InMemoryBeakDataSource` | `examples/quickstart/test/widget_test.dart` |
| A custom widget or block inside the panel | the same, plus `BeakRecordingDataSource` to fail one call | `examples/clean_beak_config/test/custom_shop_test.dart` |
| Form logic: suggestions, derived values, validation | a `BeakFormSession` over the in-memory source, no widget | `examples/clean_beak_config/test/order_form_test.dart` |
| That a save is atomic, replayable and rejected when invalid | the real server on `sqlite::memory:` | `examples/clean_beak_config/test/shop_api_test.dart` |
| Who may read or write what | the real server, one client per role | `packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart` |
| That models and migrations agree | `expectSchemaParity` over a migrated database | `examples/clean_beak_config/test/shop_migration_test.dart` |
| A `BeakDataSource` you wrote | `runBeakDataSourceContract` | `packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart` |

`beak create` writes the first row for you. This is the whole file:

```dart title="examples/quickstart/test/widget_test.dart"
import 'package:beak/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickstart/beak/app.g.dart';
import 'package:quickstart/beak/registry.g.dart';

void main() {
  testWidgets('the panel boots with every declared model registered', (
    tester,
  ) async {
    // An empty in-memory source: the panel renders its empty states, and
    // seeding one is `source.seed(const NoteModel(), [record])`.
    final source = InMemoryBeakDataSource(registry: buildBeakRegistry());
    await tester.pumpWidget(BeakApp(dataSource: source));
    await tester.pumpAndSettle();

    expect(beakModels, isNotEmpty, reason: 'no model was discovered');
    for (final model in beakModels) {
      expect(
        buildBeakRegistry().byTable(model.table),
        isNotNull,
        reason: '${model.table} is not registered',
      );
    }
  });
}
```

The generated `BeakApp` takes an optional `dataSource`. An authored panel takes the same argument on `BeakPanel(dataSource: ...)`. Leave it out and the panel talks HTTP to `apiBaseUrl`, which a widget test never wants.

## The panel over an in-memory data source

`InMemoryBeakDataSource` is a complete `BeakDataSource` over maps. It honors every operator, nested and/or filters, sorts, search, paging, eager relation loads, soft deletes and aggregates, so a passing widget test says something about filtering. A fake that returns every row whatever the spec asks for cannot say that.

Seed it with typed records. `seed` replaces a model's rows and returns the source, `seedPivot` links a many-to-many, and `rowsOf` reads back what a write stored, soft-deleted rows included.

```dart title="examples/clean_beak_config/test/shop_widget_test.dart"
      final source = InMemoryBeakDataSource(registry: registry)
        ..seed(const ProductModel(), [
          const ProductModel().record([
            ProductModel.id.to('beans'),
            ProductModel.name.to('Espresso Beans'),
            ProductModel.price.to(eur('12.50')),
          ]),
          const ProductModel().record([
            ProductModel.id.to('grinder'),
            ProductModel.name.to('Hand Grinder'),
            ProductModel.price.to(eur('1234.05')),
          ]),
        ]);
```

When you need a record and do not care what is in it, `beakFakeRecord(const ProductModel())` builds one from the model's own column metadata and rules, so a `BeakMaxLength(60)` added tomorrow cannot leave a 200-character fixture behind. `BeakRecordFactory(seed: 7)` does the same for many records and is reproducible under the seed.

The panel's layout breakpoints are wider than the default 800 by 600 test window. Widget tests that render a table or a form set a desktop-sized surface first, as the shop's do:

```dart
await tester.binding.setSurfaceSize(const Size(1440, 1080));
addTearDown(() => tester.binding.setSurfaceSize(null));
```

One widget needs no panel around it. `BeakConfiguredForm` takes the same source, so a form screen can be pumped on its own:

```dart title="examples/clean_beak_config/test/shop_widget_test.dart"
--8<-- "examples/clean_beak_config/test/shop_widget_test.dart:standaloneForm"
```

## Form logic without a screen

A `BeakFormSession` is what sits behind every form. Build one over the in-memory source, set fields, and read derived values back. There is no widget, no pump and no settle, so these tests are fast.

```dart title="examples/clean_beak_config/test/order_form_test.dart"
--8<-- "examples/clean_beak_config/test/order_form_test.dart:formLogicInMemoryTest"
```

!!! note "What just happened"
    - The suggested price follows the product until the user overrides it, and the override survives switching products. That rule is model behavior, and the test proves the client-side preview of it.
    - Nothing here says the server agrees. The preview is a convenience for the person typing. The server re-runs the same behavior on save, and that half is tested below.

## Count round trips, and fail on purpose

Rendering the right pixels is half the claim. The other half is that a list page costs one request and not one per row. `BeakRecordingDataSource` wraps any source, records every call and forwards it unchanged, so what you test is still the real thing. It keeps one list per method (`queryCalls`, `getOneCalls`, `batchGetCalls`, `createCalls`, `updateCalls`, `deleteCalls`, `restoreCalls`, `attachCalls`, `detachCalls`, `aggregateCalls`) and `clearRecordedCalls()` to count only what happens after a tap.

```dart title="packages/beak_frontend/test/src/table/beak_data_table_test.dart"
      // The relationship, not the key it stores.
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('c1'), findsNothing);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Category id'), findsNothing);
      // And it cost the one page query, not one lookup per row.
      expect(articles.queryCalls, hasLength(1));
      expect(articles.getOneCalls, isEmpty);
      expect(articles.batchGetCalls, isEmpty);
      expect(
        articles.queryCalls.single.relationLoads.single.relationKey,
        'category',
      );
```

`BeakRecordingDataSource` is a `base class`, so a subclass can make one operation fail while the rest keeps working. That is how the shop tests a custom widget's error state:

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
--8<-- "examples/clean_beak_config/test/custom_shop_test.dart:FailingAggregate"
```

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
--8<-- "examples/clean_beak_config/test/custom_shop_test.dart:retryableBillingTest"
```

The widget shows an error with a retry, not a zero. A test that only used the happy path would have passed a widget that reports "0 open invoices" while the database is down.

## The real API on in-memory SQLite

Everything the client cannot be trusted with runs on the server, so it needs a server in the test. The shop boots the generated host on an ephemeral port, migrates and seeds a fresh in-memory database, and points a `BeakClient` (the wire client the panel uses) at it:

```dart title="examples/clean_beak_config/test/support/shop_test_api.dart"
--8<-- "examples/clean_beak_config/test/support/shop_test_api.dart:ShopTestApi"
```

`beakHost(environment: {...})` is the seam. The map replaces the process environment, so the test points the real host at `sqlite::memory:` and switches uploads off without touching the machine. `Worm.reset()` in `dispose` is mandatory: worm refuses a second initialization in the same process.

Tests are then plain client calls. These two prove what a form save promises, that one plan writes the order and its lines together and survives a replay, and that a plan with an invalid child writes nothing:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
--8<-- "examples/clean_beak_config/test/shop_api_test.dart:graphSaveTests"
```

To test a form save end to end, hand the session an `HttpBeakDataSource` over that client. The session builds the same plan the panel would and the server answers with a receipt:

```dart title="examples/clean_beak_config/test/order_form_test.dart"
--8<-- "examples/clean_beak_config/test/order_form_test.dart:formSaveThroughApiTest"
```

The whole shop API suite is a few seconds of test time. Each test gets its own database, so tests do not order themselves around each other. The server logs one line per request to stderr, so the output of an API test run is chatty.

### Test the policy at the server

Authorization is the clearest case for a server test, because a widget test cannot see it. The rules below make notes readable by anyone signed in and scoped to the caller's own author. The tests then send requests through the real router with real session tokens:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
--8<-- "packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart:rowScopedQueryTests"
```

An anonymous request is a 401. A signed-in caller with no rows gets an empty page, not a 403, because a row scope narrows and does not refuse. The rules themselves are on the [Security](security.md) page.

## Migrations and schema parity

Two things belong in a test: that an upgrade preserves the data already in the database, and that the models still match the tables the migrations build.

The shop answers the first by migrating only the early part of its migration list, inserting legacy rows, running the rest and asserting the rows survived. Its `shop_migration_test.dart` also asserts the foreign keys a fresh database declares.

For the second, `expectSchemaParity` checks that every model has a table with the columns it declares (including the foreign key a belongs-to implies and `deleted_at` on soft-deleting models), and `expectNoOrphanTables` checks the reverse. The worm adapter can list what it built. This is illustrative code, compiled and run against the shop:

```dart
final live = await adapter.introspectSchema();
final actual = {
  for (final entry in live.entries) entry.key: entry.value.toSet(),
};
expectSchemaParity(registry: buildBeakRegistry(), actual: actual);
expectNoOrphanTables(
  registry: buildBeakRegistry(),
  actual: actual,
  ignoreTables: {'_beak_commit_receipts', '_beak_outbox'},
);
```

`expectNoOrphanTables` knows the tables of common migration tools but not Beak's own two, the commit receipts and the outbox, so list them in `ignoreTables` until it does.

## Your own data source

If you wrote a `BeakDataSource` (see [Custom data sources](../extending/custom-data-sources.md)), run the shared contract against it. It is the ten-method interface as an executable specification, including the sharp edges: `getOne` returns null rather than throwing, `update` throws when the row is gone, `aggregate` returns 0 over nothing, soft deletes hide from `query` but not from `withTrashed`. Eager loads (plain, filtered and nested), `attach` and `detach` run for the models you name in `relationModels`. Beak's own worm-backed source is held to the same suite:

```dart title="packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart"
--8<-- "packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart:contract"
```

## Failure paths worth a test

Happy paths are the cheap ones. These are the cases that break in production:

- A relationship selection that is invalid or no longer available.
- A field hidden by presentation but required by the server.
- A rollback after a child fails, and a duplicate named action.
- An unknown outcome (the response was lost) followed by recovery with the same save id.
- A stale draft restored after the schema changed.
- A rejected write, and the field errors it should carry back.
- A read-only or pending surface that must not mutate its draft.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| `InMemoryBeakDataSource` does not implement graph commits | A form saved against it runs as sequential, non-atomic writes (`BeakSaveMode.staged`). Atomicity, replay and receipts need the real server. |
| It runs no server-side validation, model behavior, preparer or policy | A green widget test proves the client half. Test rules, behavior and authorization against the API. |
| Uploads and CSV export are server features, not data-source operations | Test them through the server, with `BEAK_STORAGE_DRIVER=memory` or `local` in the environment map. |
| Generated ids are sequential (`id-1`, `id-2`), shared across instances in one process | Do not assert on a generated id. Seed rows with explicit ids, or read the id back from the result. |
| `sqlite::memory:` is SQLite | Types, case sensitivity and locking can differ from Postgres. Run the same suite against a throwaway Postgres database before a release. |
| `MigrationRunner.fresh` rolls back every applied migration and applies them again | That erases the data in those tables. Point it only at a database you can lose. |
| worm allows one initialization per process | Call `Worm.reset()` in every teardown that started a host. |

A test that needs real services (Postgres, MinIO) belongs behind a tag your default run excludes, so a machine without Docker still runs everything else. Beak's own repository does this with an `e2e` tag; [Writing tests](../contributing/writing-tests.md) describes that setup.

## Verify it

Run the shop's two suites as a check that your environment builds and runs them:

```console
$ cd examples/clean_beak_config
$ flutter test test/custom_shop_test.dart test/shop_api_test.dart
...
00:04 +21: All tests passed!
```

Between those two files, 21 tests pass in a few seconds of test time. In your own project the same command shape is `flutter test`, and API tests carry `@TestOn('vm')`. To check that the models and the migrations still agree from the command line, `beak doctor` reports drift against the database `DATABASE_URL` names, and exits non-zero on a failed check (a WARN does not fail the run):

```console
$ beak doctor
  OK   generated files up to date
  OK   every model has a migration
  WARN invoices.subtotal is declared by Invoice.subtotal but missing from the database
       → write a migration with `beak make:migration`, then `migrate`
```

## Reference

- `packages/beak_test/lib/src/in_memory_beak_data_source.dart`, `beak_recording_data_source.dart`, `beak_record_factory.dart`, `beak_schema_parity.dart` and `data_source_contract.dart` are the toolkit. `package:beak/testing.dart` re-exports all of it.
- [Query contract](../architecture/query-contract.md) is the spec the in-memory source implements.
- [Graph commits](../architecture/graph-commits.md) explains the receipts the API tests assert on.
- [Writing tests](../contributing/writing-tests.md) is the contributor view: which runner and coverage floor each Beak package uses.

## Continue reading

- [Security](security.md) the policy rules the server tests above exercise.
- [Going to production](going-to-production.md) what to run after the tests pass.
- [Results and errors](../concepts/results-and-errors.md) the typed exceptions and receipts your assertions read.
