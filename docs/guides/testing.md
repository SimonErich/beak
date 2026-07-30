---
title: Testing
description: The test seams Beak ships: an in-memory data source for the panel, a recording decorator for round-trip counts, your whole API on sqlite::memory: and again on Postgres, and the coverage gate.
---

# Testing

Beak was built test-first, so every layer already has a seam you can push a fake
through. After this page you can test a resource end to end without a live
server: render the panel against an in-memory data source, count the round trips
a screen costs, run your whole API against `sqlite::memory:` on every push and
against Postgres on demand, and satisfy the coverage gate.

## The seams

There is one seam per layer, and each one lets a test replace the layer below it
with something fast and deterministic. The first four ship in
`package:beak/testing.dart`, so an app gets them without writing a fake.

| Seam | Where | What it replaces | Used for |
| --- | --- | --- | --- |
| `InMemoryBeakDataSource` | panel widget tests | the network and the server | render the panel, forms and blocks against real filtering, sorting, paging and eager loading |
| `BeakRecordingDataSource` | panel widget tests | nothing, it decorates | assert how many round trips a screen costs and what was in each spec |
| `BeakRecordFactory` / `beakFakeRecord` | any test | hand-written fixtures | build records from the model's own column metadata, so a new rule cannot leave a fixture behind |
| `runBeakDataSourceContract` | data-source tests | nothing | prove a `BeakDataSource` you wrote behaves like the built-in ones |
| `DATABASE_URL=sqlite::memory:` | API tests | Postgres and MinIO | boot your real server, migrations, policy and routes in seconds |
| worm `InMemoryAdapter` + `LoggingAdapter` | `beak_backend` logic tests | Postgres | drive the real Shelf handlers in memory and count the queries a request runs |
| Golden `BeakQuerySpec` JSON | `beak_core` unit tests | nothing, it pins the contract | catch any accidental change to the wire format |

The rules behind all of them live in
[Writing tests](../contributing/writing-tests.md): write the smallest failing
test first, never weaken a test to go green, and never hit a real network in a
widget test.

## Frontend: render the panel against an in-memory data source

The generated `BeakApp` takes an optional `dataSource`. Pass one and the whole
panel runs against it, no HTTP client in sight. The frontend flow is Widget then
ViewModel then Repository then DataSource, so swapping the data source swaps the
bottom of the whole stack.

`InMemoryBeakDataSource` is a complete `BeakDataSource` over maps. Complete is
the operative word: it honours every `BeakOperator`, nested and/or filters,
sorts, search, pagination, eager relation loads, soft deletes and aggregates. A
green widget test therefore proves something about filtering, which a fake that
returned every row regardless of the spec never did.

```dart title="examples/store/test/widget_test.dart"
final registry = buildBeakRegistry();
final source = InMemoryBeakDataSource(registry: registry)
  ..seed(const ProductModel(), [
    BeakRecord.fromRow(const {
      'id': 'p1',
      'name': 'Espresso Beans',
      'sku': 'COF-ESP-1KG',
      'price': 12.5,
      'stock': 42,
      'featured': true,
      'status': 'published',
    }),
  ]);

// A desktop-sized surface: the default 800×600 test window is narrower
// than the panel's own layout breakpoints.
await tester.binding.setSurfaceSize(const Size(1600, 1200));
addTearDown(() => tester.binding.setSurfaceSize(null));
await tester.pumpWidget(BeakApp(dataSource: source));
await tester.pumpAndSettle();
```

!!! note "What just happened"
    - The registry comes from `buildBeakRegistry()`, generated from your schema
      classes, so the source knows every model's columns, relationships and
      soft-delete flag without being told twice.
    - `seed` takes typed `BeakRecord`s and returns the source, so seeding chains
      off the constructor. `seedPivot` sets up a many-to-many the same way.
    - The panel built its shell, router and generated pages exactly as it would
      in production. Nothing was mocked.

The same seam works on one widget. Hand `BeakDataForm` or `BeakDataTable` the
source directly and pump it on its own.

Need a record and do not care what is in it? `beakFakeRecord(const
ProductModel())` builds one from the model's own column metadata, obeying its
rules, so a `BeakMaxLength(60)` added today cannot leave a 200-character fixture
behind.

To test a failure path, override the one method under test and throw a typed
exception from it. `InMemoryBeakDataSource` is `final`, but
`BeakRecordingDataSource` is a `base class`, so wrap the in-memory source in a
subclass of the recorder and everything you did not override keeps working. The
form maps a `BeakValidationException` back onto the offending fields and
surfaces anything else as a global error.

```dart
final class RejectingSource extends BeakRecordingDataSource {
  RejectingSource(super.inner);

  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakValidationException(
      'Validation failed.',
      fieldErrors: {
        'name': ['Already taken.'],
      },
    );
  }
}
```

## Counting round trips

Rendering the right pixels is half the claim. The other half is that a list page
costs one query and not one per row. `BeakRecordingDataSource` wraps any source,
records every call, and forwards it unchanged, so the behaviour under test is
still the real thing.

It exposes one list per method (`queryCalls`, `getOneCalls`, `batchGetCalls`,
`createCalls`, `updateCalls`, `deleteCalls`, `restoreCalls`, `attachCalls`,
`detachCalls`, `aggregateCalls`) plus `clearRecordedCalls()` for counting only
what happened after a tap.

Beak's own panel suites use exactly this shape: a `FakeDataSource` that is a
`BeakRecordingDataSource` over an `InMemoryBeakDataSource`. Here it pins the
N+1 proof for a table that renders a foreign key.

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

## Your API, asserted once and run twice

The panel is only half an app. The other half is the generated REST API, your
migrations, your seeders and your row policy, and the fastest honest way to test
those is to boot the real server on an in-memory database.

The store writes its whole API suite once, as a function that takes the
environment to run the server in:

```dart title="examples/store/test/api_scenario.dart"
void runStoreApiScenario({
  required Map<String, String> Function(int port) environmentFor,
  required String description,
}) {
```

Inside, it binds a free port, builds the generated host with that environment,
runs `MigrationRunner(...).fresh(seed: true)`, starts the server and points a
`BeakClient` at it. The tests that follow are plain client calls: paging,
sorting, search, eager loading, validation, uploads with variants, soft delete
and restore, pivot attach and detach, global search, CSV export, aggregates,
optimistic concurrency, and the row policy.

One file runs it on SQLite. No Docker, no services, seconds to run, so it goes
in the main gate:

```dart title="examples/store/test/api_sqlite_test.dart"
  runStoreApiScenario(
    description: 'store API on sqlite',
    environmentFor: (port) => {
      'DATABASE_URL': 'sqlite::memory:',
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      // Served by the Beak server itself, so an uploaded file's URL resolves
      // with nothing else running.
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
```

A second file runs the identical assertions against Postgres from
`docker-compose.yml`, under the `e2e` tag:

```dart title="examples/store/test/e2e/postgres_test.dart"
  runStoreApiScenario(
    description: 'store API on postgres',
    environmentFor: (port) => {
      'DATABASE_URL': databaseUrl.toString(),
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
```

!!! note "What just happened"
    - The only difference between the two runs is `DATABASE_URL`. Everything
      else, including every assertion, is shared.
    - The Postgres file derives its database name rather than trusting the
      environment: an exported `DATABASE_URL` may vary the host and credentials,
      but a fresh-migrate only ever lands in a database whose name ends in
      `_store_e2e`.
    - Suites under `test/e2e/` carry `@Tags(['e2e'])`, and the main gate runs
      with `--exclude-tags e2e`, so a machine with no Docker still runs
      everything the SQLite file asserts.

!!! question "What this skipped"
    Bring the services up with `melos run up` before
    `melos run test-e2e`. What the Postgres run adds is the half a driver can
    differ on: real `uuid` columns, real `ilike`, real transactions. See
    [The data source seam](../backend/the-data-source-seam.md) for how
    `WormDataSource` sits behind the interface both runs share.

## Backend: drive the real handlers over an in-memory database

Beak's own backend logic tests do not mock the service or the data source. They
stand up the real `beakApiRouter` over a `WormDataSource` backed by worm's
`InMemoryAdapter`, then send real Shelf `Request`s through it. Reach for this
shape when you are testing a handler or middleware in isolation rather than a
whole app; for an app, booting the real server on `sqlite::memory:` is less
setup and proves more.

The harness connects a fresh adapter, creates the schema, and initializes worm.
Pair it with `tearDown(Worm.reset)`: worm throws on a double-init, so the reset
is mandatory, and a fresh adapter per test keeps them isolated.

```dart title="packages/beak_backend/test/support/api_models.dart"
--8<-- "packages/beak_backend/test/support/api_models.dart:createApiTestDatabase"
```

The endpoint suite wires that adapter into the router. It injects `now` and
`generateId` so timestamps and minted ids are deterministic, and wraps the adapter
in a `LoggingAdapter` so a test can count the queries a request runs.

```dart title="packages/beak_backend/test/src/endpoints/crud_handlers_test.dart"
setUp(() async {
  Worm.seedRandom(42);
  currentNow = fixedNow;
  final inner = await createApiTestDatabase();
  logger = InMemoryQueryLogger();
  final registry = createApiRegistry();
  mintedIds = 0;
  handler = const Pipeline()
      .addMiddleware(beakJsonMiddleware())
      .addMiddleware(beakErrorMappingMiddleware())
      .addHandler(
        beakApiRouter(
          registry: registry,
          dataSource: WormDataSource(
            registry,
            adapter: LoggingAdapter(
              inner: inner,
              logger: logger,
              strictness: const StrictnessConfig(),
              adapterName: 'InMemory',
            ),
            now: () => currentNow,
          ),
          now: () => currentNow,
          generateId: () => 'minted-${++mintedIds}',
        ),
      );
});

tearDown(Worm.reset);
```

A small `call` helper turns a method and path into a `Request` through the handler,
so each test reads like an HTTP transcript.

```dart title="packages/beak_backend/test/src/endpoints/crud_handlers_test.dart"
  Future<Response> call(String method, String path, {Object? body}) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );
```

Now a test is a request and a set of assertions on the status and JSON body. The
create test proves the service minted an id and stamped timestamps.

```dart title="packages/beak_backend/test/src/endpoints/crud_handlers_test.dart"
    test('returns 201 with a minted id and stamped timestamps', () async {
      final response = await call(
        'POST',
        '/api/notes',
        body: {'title': 'Grocery run', 'rating': 4},
      );
```

The `LoggingAdapter` earns its place on the N+1 proof. Loading a paged list with a
pivot relation should stay at a fixed number of queries no matter how many rows come
back. The test pins it.

```dart title="packages/beak_backend/test/src/endpoints/crud_handlers_test.dart"
        const spec = BeakQuerySpec(
          table: 'notes',
          relationLoads: [BeakRelationLoad('labels')],
        );
        await call('POST', '/api/notes/query', body: spec.toJson());

        // count + parent select + pivot select + related select.
        expect(logger.entries, hasLength(4));
```

## Testing a data source you wrote

"Implement ten methods" is not a specification. `getOne` returns null rather
than throwing, `update` throws when the row is gone, `aggregate` returns 0
rather than null over an empty set, soft deletes hide from `query` but not from
`withTrashed`. `runBeakDataSourceContract` is those rules as an executable
suite. Point it at a builder and a seeder and it runs the whole contract against
your source:

```dart
void main() {
  runBeakDataSourceContract(
    'MyDataSource',
    registry: buildBeakRegistry(),
    model: const ProductModel(),
    create: () async => MyDataSource(),
    seed: (source, model, records) async => mySeed(source, model, records),
  );
}
```

Beak's own `InMemoryBeakDataSource` runs the same suite, so passing it means
your source behaves like the reference one.

→ [Custom data sources](../extending/custom-data-sources.md).

## Checking a model against its schema

`expectSchemaParity` fails when a model declares a table or a column the
database does not have, or the other way round. Feed it the registry and
whatever your stack can introspect:

```dart
test('every model has its table', () async {
  expectSchemaParity(
    registry: buildBeakRegistry(),
    actual: await introspect(adapter),
  );
});
```

`beakSchemaParityProblems` is the same check returning the list instead of
failing, for a tool that is not a test.

## Pinning the wire format with a golden

`BeakQuerySpec` is the contract the frontend and backend both speak, so an
accidental change to its JSON shape is a breaking change. `beak_core` guards it two
ways: it pins the exact map for representative specs, and it diffs a rich spec
against a committed golden file.

The compact version asserts the full map for an empty spec, so a new field or a
renamed key fails loudly.

```dart title="packages/beak_core/test/src/query/beak_query_spec_test.dart"
    test('an empty spec pins the exact JSON map', () {
      expect(const BeakQuerySpec(table: 'products').toJson(), {
        'table': 'products',
        'filter': null,
        'sorts': <Object?>[],
        'search': null,
        'relations': <Object?>[],
        'pagination': {'page': 1, 'perPage': 25},
        'withTrashed': false,
      });
    });
```

The golden test builds a spec with a filter, a sort, a search, a relation load, and
pagination, then checks it against the file on disk both ways: the spec must encode
to the golden bytes, and the golden must decode back to an equal spec.

```dart title="packages/beak_core/test/src/query/beak_query_spec_test.dart"
  group('golden', () {
    final goldenFile = File('test/golden/rich_query_spec.json');

    test('the rich spec matches the committed golden JSON file', () {
      final golden = goldenFile.readAsStringSync();
      expect(jsonDecode(golden), richSpec().toJson());
      const encoder = JsonEncoder.withIndent('  ');
      expect('${encoder.convert(richSpec().toJson())}\n', golden);
    });

    test('the committed golden decodes back to the rich spec', () {
      final spec = switch (jsonDecode(goldenFile.readAsStringSync())) {
        final Map<String, Object?> map => BeakQuerySpec.fromJson(map),
        final Object? other => fail('golden must be a JSON object, got $other'),
      };
      expect(spec, richSpec());
    });

    // ...
  });
```

The file it checks against is committed, so a diff in review shows the format change
in plain sight.

```json title="packages/beak_core/test/golden/rich_query_spec.json"
--8<-- "packages/beak_core/test/golden/rich_query_spec.json"
```

## Where tests live and how to run them

Tests mirror `lib/src/...` under `test/...`. Pure-Dart packages run with
`dart test`; Flutter packages and example apps run with `flutter test`. One
command runs the lot, across `packages/**` and `examples/**`:

```bash
melos run test
```

That fans out into the per-toolchain scripts, so you can run just one while you work:

```bash
melos exec --scope="beak_core" -- dart test        # one Dart package
melos exec --scope="store" -- flutter test         # the store example
```

Service-backed suites live under `test/e2e/`, are tagged `e2e`, and are excluded
from `melos run test`. Run them on purpose:

```bash
melos run up          # Postgres + MinIO, waits for health
melos run test-e2e    # every test/e2e directory, --tags e2e
```

## The coverage gate

Coverage is a gate, not a vanity number. `melos run coverage` computes line coverage
per package and fails if any package is under its floor. The default is 85%, with
overrides both ways.

```dart title="tool/check_coverage.dart"
/// Default line-coverage threshold (in percent) for gated packages.
const int defaultThresholdPct = 85;

/// Per-package threshold overrides, keyed by package directory name.
const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  // A testing toolkit whose own tests are thin would be a poor advert.
  'beak_test': 90,
  'quickstart': 50,
  'store': 70,
  'superdashboard': 85,
  'embedded': 85,
};
```

`beak_core` is pure Dart with no I/O, so it holds at 100%. `quickstart` and
`store` hold a lower bar on purpose: most of what an example declares is data (a
screen's block tree, a resource's actions) that a widget suite instantiates
without executing line by line. What has to work is checked directly instead, by
the API scenario
and by the coverage matrices in `examples/store/test/widget_test.dart` that fail
when a column kind or a relationship kind stops being demonstrated.

The floor is there to keep you honest about branches and error paths, not just
happy paths: a package at 90% coverage with an untested failure mode has not
really passed.

!!! tip "Run coverage on a clean tree"
    `melos run coverage` reads the lcov report each package's test run produced, so
    run `melos run test` first, and delete stale `packages/*/coverage` and
    `examples/*/coverage` directories, to make sure it grades this run and not
    the last one.

## Continue reading

- [Writing tests](../contributing/writing-tests.md) the red, green, refactor loop and
  the per-package conventions.
- [Results and errors](../concepts/results-and-errors.md) the exception family your
  backend tests assert on.
- [How data flows](../concepts/how-data-flows.md) the `BeakQuerySpec` the golden test
  pins.
- [The data source seam](../backend/the-data-source-seam.md) why the same
  `BeakDataSource` interface serves both the in-memory source and the real database.
- [Libraries](../reference/libraries.md) what each `package:beak/*.dart` entry point
  exports, `testing.dart` included.
