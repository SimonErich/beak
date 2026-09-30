# Testing

> Test a Beak project at three levels, the panel over an in-memory data source, form logic with no screen, and the real API on in-memory SQLite.

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

`InMemoryBeakDataSource` is a complete `BeakDataSource` over maps. It honors every operator, nested and/or filters, sorts, search, paging, eager relation loads, soft deletes and aggregates, so a passing widget test says something about filtering. A fake that returns every row whatever the spec asks for cannot say that. It also refuses what the real store refuses: a second row under a taken key is a `BeakConflictException`, attaching to an owner that does not exist is a `BeakNotFoundException`, and `contains`, `startsWith` and `endsWith` ignore case.

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
await tester.pumpWidget(
  BeakFormattingScope(
    formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
    child: OiApp(
      theme: OiThemeData.light(),
      home: BeakConfiguredForm(
        model: const FulfillmentPolicyModel(),
        registry: registry,
        dataSource: InMemoryBeakDataSource(registry: registry),
        mode: BeakFormMode.create,
        layout: fulfillmentPolicyForm(),
        onSession: (value) => session = value,
      ),
    ),
  ),
);
```

## Form logic without a screen

A `BeakFormSession` is what sits behind every form. Build one over the in-memory source, set fields, and read derived values back. There is no widget, no pump and no settle, so these tests are fast.

```dart title="examples/clean_beak_config/test/order_form_test.dart"
test(
  'model suggestions follow catalog changes until the price is overridden',
  () async {
    final registry = buildBeakRegistry();
    final source = InMemoryBeakDataSource(registry: registry);
    final session = BeakFormSession(
      model: const OrderModel(),
      registry: registry,
      dataSource: source,
      steps: orderSteps(),
    );
    addTearDown(session.dispose);
    final first = const ProductModel().record([
      ProductModel.id.to('a'),
      ProductModel.name.to('First'),
      ProductModel.price.to(eur('12.50')),
    ]);
    final second = const ProductModel().record([
      ProductModel.id.to('b'),
      ProductModel.name.to('Second'),
      ProductModel.price.to(eur('20.00')),
    ]);
    source.seed(const ProductModel(), [first, second]);
    final row = session.root.addRow(OrderModel.items);
    row.select(OrderItemModel.product, first);
    expect(row.read(OrderItemModel.overwritePrice), eur('12.50'));
    expect(row.read(OrderItemModel.label), 'First');
    row.select(OrderItemModel.product, second);
    expect(row.read(OrderItemModel.overwritePrice), eur('20.00'));
    expect(row.read(OrderItemModel.label), 'Second');
    row.set(OrderItemModel.overwritePrice, eur('7.00'));
    row.select(OrderItemModel.product, first);
    expect(row.read(OrderItemModel.overwritePrice), eur('7.00'));
    expect(row.read(OrderItemModel.label), 'First');
  },
);
```

> **Note: What just happened**
>
> - The suggested price follows the product until the user overrides it, and the override survives switching products. That rule is model behavior, and the test proves the client-side preview of it.
> - Nothing here says the server agrees. The preview is a convenience for the person typing. The server re-runs the same behavior on save, and that half is tested below.

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
final class _FailingAggregate extends BeakRecordingDataSource {
  _FailingAggregate(super.inner);
  bool fail = true;
  @override
  Future<num> aggregate(BeakAggregateSpec spec) => fail
      ? Future.error(const BeakStorageException('Unavailable'))
      : super.aggregate(spec);
}
```

```dart title="examples/clean_beak_config/test/custom_shop_test.dart"
testWidgets(
  'custom billing widget shows a retryable error without a false zero',
  (tester) async {
    final registry = buildBeakRegistry();
    final source = _FailingAggregate(
      InMemoryBeakDataSource(registry: registry),
    );
    await tester.pumpWidget(
      BeakPanel(
        pages: [
          BeakScreen(
            path: '/',
            title: 'Billing',
            icon: const BeakIconToken(OiIcons.receiptText),
            body: BeakWidgetBlock((_) => const ShopReceivablesCard()),
          ),
        ],
        resources: [InvoiceResource()],
        dataSource: source,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text('All clear. No issued invoices are awaiting payment.'),
      findsNothing,
    );
    source.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('All clear. No issued invoices are awaiting payment.'),
      findsOneWidget,
    );
  },
);
```

The widget shows an error with a retry, not a zero. A test that only used the happy path would have passed a widget that reports "0 open invoices" while the database is down.

## The real API on in-memory SQLite

Everything the client cannot be trusted with runs on the server, so it needs a server in the test. The shop boots the generated host on an ephemeral port, migrates and seeds a fresh in-memory database, and points a `BeakClient` (the wire client the panel uses) at it:

```dart title="examples/clean_beak_config/test/support/shop_test_api.dart"
/// Real transactional example API for form-to-server integration tests.
final class ShopTestApi {
  ShopTestApi._(this.adapter, this.server, this.client);

  /// Isolated, in-memory SQLite database.
  final DatabaseAdapter adapter;

  /// HTTP server on an ephemeral loopback port.
  final HttpServer server;

  /// The same wire client used by the panel.
  final BeakClient client;

  /// Migrates and seeds a fresh database without touching the example's file.
  static Future<ShopTestApi> start() async {
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final host = beakHost(
      environment: {
        'DATABASE_URL': 'sqlite::memory:',
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'BEAK_STORAGE_DRIVER': 'none',
      },
    );
    final adapter = adapterFromUrl(host.config.databaseUrl);
    await adapter.connect();
    await MigrationRunner(
      adapter: adapter,
      migrations: host.migrations,
      seeders: host.seeders,
    ).fresh(seed: true);
    final server = await host.buildServer(adapter: adapter).start();
    return ShopTestApi._(
      adapter,
      server,
      BeakClient(baseUrl: 'http://127.0.0.1:$port'),
    );
  }

  /// Releases all transport and database state after the test.
  Future<void> dispose() async {
    client.close();
    await server.close(force: true);
    await adapter.disconnect();
    await Worm.reset();
  }
}
```

`beakHost(environment: {...})` is the seam. The map replaces the process environment, so the test points the real host at `sqlite::memory:` and switches uploads off without touching the machine. `Worm.reset()` in `dispose` is mandatory: worm refuses a second initialization in the same process.

Tests are then plain client calls. These two prove what a form save promises, that one plan writes the order and its lines together and survives a replay, and that a plan with an invalid child writes nothing:

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
test(
  'one final graph save creates owned lines and survives replay',
  () async {
    final plan = _orderPlan('valid-order', quantity: 2);
    final result = await client.commit(plan);
    expect(result.complete, isTrue, reason: '${result.toJson()}');
    expect(result.mode, BeakSaveMode.atomic);
    final replayed = await client.commit(plan);
    expect(replayed.identities, result.identities);
    final recovered = await client.recoverCommit(plan.saveId);
    expect(recovered.identities, result.identities);

    final orders = await client.query(
      'orders',
      const OrderModel().query(
        filter: OrderModel.reference.eq('SHOP-001'),
        relationLoads: const [BeakRelationLoad('items')],
      ),
    );
    expect(orders.total, 1);
    expect(orders.items.single.asOrder.items.single.quantity, 2);
    expect(orders.items.single.asOrder.customerId, ShopSeedIds.ada);
  },
);

test(
  'invalid child validation leaves the whole order graph unapplied',
  () async {
    final result = await client.commit(
      _orderPlan('invalid-order', quantity: 0),
    );
    expect(result.complete, isFalse);
    expect(
      result.outcomes.every(
        (outcome) => outcome.status == BeakWriteOutcome.unapplied,
      ),
      isTrue,
    );
    final orders = await client.query('orders', const OrderModel().query());
    expect(orders.total, 1);
    expect(orders.items.single.asOrder.id, ShopSeedIds.order);
  },
);
```

To test a form save end to end, hand the session an `HttpBeakDataSource` over that client. The session builds the same plan the panel would and the server answers with a receipt:

```dart title="examples/clean_beak_config/test/order_form_test.dart"
test(
  'the actual configured wizard binds, calculates and saves its draft',
  () async {
    final registry = buildBeakRegistry();
    final api = await ShopTestApi.start();
    addTearDown(api.dispose);
    final source = HttpBeakDataSource(api.client);
    final customer = (await source.getOne(
      const UserModel().table,
      ShopSeedIds.ada,
    ))!;
    final profile = (await source.getOne(
      const UserProfileConnectionModel().table,
      ShopSeedIds.adaProfile,
    ))!;
    final product = (await source.getOne(
      const ProductModel().table,
      ShopSeedIds.beans,
    ))!;
    final before = (await source.query(const OrderModel().query())).total;
    final session = BeakFormSession(
      model: const OrderModel(),
      dataSource: source,
      registry: registry,
      steps: orderSteps(),
    );
    addTearDown(session.dispose);
    expect(await session.validateStep(0), isFalse);
    session.root.set(OrderModel.reference, 'SHOP-001');
    session.root.select(OrderModel.customer, customer);
    expect(await session.validateStep(0), isTrue);
    session.root.select(OrderModel.profile, profile);
    session.root.set(OrderModel.deliveryDate, DateTime.utc(2200));
    final row = session.root.addRow(OrderModel.items);
    row.set(OrderItemModel.quantity, 2);
    row.select(OrderItemModel.product, product);
    expect(lineTotal(BeakFormReader(row)), eur('25.00'));
    final checkpoint = row.checkpoint();
    row.set(OrderItemModel.discount, eur('5'));
    expect(lineTotal(BeakFormReader(row)), eur('20.00'));
    row.restore(checkpoint);
    expect(lineTotal(BeakFormReader(row)), eur('25.00'));
    expect((await source.query(const OrderModel().query())).total, before);
    final result = await session.save();
    expect(
      result?.complete,
      isTrue,
      reason:
          '${session.error.value}; root=${session.root.errors}; row=${row.errors}; result=${result?.toJson()}',
    );
    expect(
      (await source.query(const OrderModel().query())).total,
      before + 1,
    );
    expect(
      (await source.query(
        const OrderItemModel().query(
          filter: OrderItemModel.orderId.eq(result!.rootRecord!.asOrder.id),
        ),
      )).items.single.asOrderItem.quantity,
      2,
    );
  },
);
```

The whole shop API suite is a few seconds of test time. Each test gets its own database, so tests do not order themselves around each other. The server logs one line per request to stderr, so the output of an API test run is chatty.

### Test the policy at the server

Authorization is the clearest case for a server test, because a widget test cannot see it. The rules below make notes readable by anyone signed in and scoped to the caller's own author. The tests then send requests through the real router with real session tokens:

```dart title="packages/beak_backend/test/src/auth/beak_policies_handlers_test.dart"
test('query: 401 anonymous, then a page scoped to the caller', () async {
  expect(
    (await call('POST', '/api/notes/query', body: querySpec)).statusCode,
    401,
  );
  final mine = await call(
    'POST',
    '/api/notes/query',
    body: querySpec,
    token: editorToken,
  );
  expect(mine.statusCode, 200);
  final items = await itemsOf(mine);
  expect(items, hasLength(1));
  expect(jsonEncode(items), contains('Mine'));
  expect(jsonEncode(items), isNot(contains('Theirs')));
});

test(
  'query: a signed-in caller with no rows gets an empty page, not a 403',
  () async {
    final response = await call(
      'POST',
      '/api/notes/query',
      body: querySpec,
      token: readerToken,
    );
    expect(response.statusCode, 200);
    final page = await objectOf(response);
    expect(page['items'], isEmpty);
    expect(page['total'], 0);
  },
);
```

An anonymous request is a 401. A signed-in caller with no rows gets an empty page, not a 403, because a row scope narrows and does not refuse. The rules themselves are on the [Security](security.md) page.

## Migrations and schema parity

Two things belong in a test: that an upgrade preserves the data already in the database, and that the models still match the tables the migrations build.

The shop answers the first by migrating only the early part of its migration list, inserting legacy rows, running the rest and asserting the rows survived. Its `shop_migration_test.dart` also asserts the foreign keys a fresh database declares.

For the second, `expectSchemaParity` checks that every model has a table with the columns it declares (including the foreign key a belongs-to implies and `deleted_at` on soft-deleting models), and `expectNoOrphanTables` checks the reverse. The worm adapter can list what it built. This block is illustrative (it is not a repository file). It compiled and passed against a fresh `beak create` project after `MigrationRunner.migrate()`:

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
runBeakDataSourceContract(
  'WormDataSource',
  registry: _contractRegistry(),
  model: const NoteModel(),
  create: () async {
    adapter = await createApiTestDatabase();
    return WormDataSource(_contractRegistry(), adapter: adapter);
  },
  seed: (source, model, records) async {
    for (final record in records) {
      await adapter.insert(
        InsertDescriptor(table: model.table, values: record.toRow()),
      );
    }
  },
  sortableTextColumn: NoteColumns.title,
  numericColumn: NoteColumns.rating,
  relationModels: const [NoteModel(), _AuthorWithNotesModel()],
  seedLinks: (source, relation, ownerId, relatedIds) async {
    for (final relatedId in relatedIds) {
      await adapter.insert(
        InsertDescriptor(
          table: relation.pivotTable,
          values: {
            relation.foreignPivotKey: ownerId,
            relation.relatedPivotKey: relatedId,
          },
        ),
      );
    }
  },
);
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
All tests passed!
```

Both files pass in a few seconds of test time. In your own project the same command shape is `flutter test`, and API tests carry `@TestOn('vm')`. To check that the models and the migrations still agree from the command line, `beak doctor` reports drift against the database `DATABASE_URL` names, and exits non-zero on a failed check (a WARN does not fail the run):

```console
$ beak doctor
  OK   generated files up to date
  OK   every model has a migration
  WARN invoices.subtotal is declared by Invoice.subtotal but missing from the database
       → beak make:migration AddSubtotalToInvoices --from-drift, then beak migrate
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
