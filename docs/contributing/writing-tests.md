---
title: Writing tests
description: Where tests live per package and the harness each one uses: pure units for core, an InMemoryAdapter for the backend, the beak_test toolkit for the panel, golden JSON, and the coverage floor.
---

# Writing tests

After this page you can add a test to any Beak package using the harness that
package expects: a pure unit for `beak_core`, worm's `InMemoryAdapter` for the
backend, the `beak_test` toolkit for the panel, and a golden file to pin a wire
shape. Every change is written test-first, red before green, and has to clear the
coverage floor.

## The loop

The workflow is red, green, refactor, per unit of behavior:

1. **RED**: write the smallest test for the next behavior. Run it. Confirm it
   fails for the right reason (a missing type or wrong result, not a typo in the
   test).
2. **GREEN**: write the minimum code to pass. Nothing speculative.
3. **REFACTOR**: clean names, remove duplication, keep the test green.

Never weaken, skip, or delete a test to go green, and never `// ignore:` a lint
to pass analysis; fix the code. Prefer many small tests over a few broad ones.

## Where tests live

Mirror the `lib/src/...` path under `test/...`. Which runner depends on the
package:

| Package                 | Runner          | Harness                                       |
| ----------------------- | --------------- | --------------------------------------------- |
| `beak_core`             | `dart test`     | pure units, zero I/O                          |
| `beak_test`             | `dart test`     | its own contract suite, run against itself    |
| `beak_backend` (logic)  | `dart test`     | worm `InMemoryAdapter`, drive Shelf directly  |
| `beak_cli`              | `dart test`     | temp-directory projects, generate and compare |
| `beak_frontend`         | `flutter test`  | `flutter_test` plus the `beak_test` toolkit   |
| `beak` (umbrella)       | `flutter test`  | asserts what each library entry point exports |
| `examples/*`            | `flutter test`  | the real panel and the real server            |
| the workspace root      | `dart test`     | the gate tooling itself (`tool/*.dart`)       |

Suites that need Postgres or MinIO go in `test/e2e/`, carry
`@Tags(['e2e'])`, and are excluded from `melos run test`. `melos run test-e2e`
runs every `test/e2e` directory after `melos run up`.

## beak_core: pure units and golden JSON

`beak_core` is pure Dart, so its tests do no I/O and aim for 100% coverage. Rules
are tested per rule, and any type that crosses the wire gets a **golden** test:
encode, compare to a committed JSON file, and decode back to an equal value.
`BeakQuerySpec` is the headline case, because it is the contract the frontend and
backend both speak.

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

The golden file is checked in, so an accidental change to the serialized shape
turns into a failing diff a reviewer sees. Pair it with a `fromJson` validation
group that asserts the parser rejects missing or wrongly typed keys; that is
where the "never leak `dynamic`" promise is actually enforced.

## beak_test: the toolkit every suite shares

`packages/beak_test` holds the fakes, so nobody hand-rolls one. It is published
to app authors as `package:beak/testing.dart`, which means a bug in it is a bug
in everyone's tests. Its own floor is 90%.

| Symbol | What it is |
| --- | --- |
| `InMemoryBeakDataSource` | a complete `BeakDataSource` over maps: every operator, nested filters, sorts, search, pagination, eager loads, soft deletes, aggregates |
| `BeakRecordingDataSource` | a decorator that records every call and forwards it unchanged, for round-trip counts |
| `BeakRecordFactory` / `beakFakeRecord` | records derived from a model's own column metadata and rules, deterministic under a seed |
| `runBeakDataSourceContract` | the ten-method interface as an executable definition of done |
| `expectSchemaParity` / `beakSchemaParityProblems` | model versus migration agreement, as an assertion and as a plain list |

Two rules when you touch it. Any new `BeakDataSource` behaviour goes into
`runBeakDataSourceContract` first, so every implementation is held to it. And
`InMemoryBeakDataSource` runs that same contract against itself:

```dart title="packages/beak_test/test/src/in_memory_beak_data_source_test.dart"
  // The full interface contract, run against the reference implementation.
  runBeakDataSourceContract(
    'InMemoryBeakDataSource',
    registry: buildContractRegistry(),
    model: _product,
    create: () async => sourceWith(),
    seed: (source, model, records) async =>
        (source as InMemoryBeakDataSource).seed(model, records),
    sortableTextColumn: ProductColumns.name,
    numericColumn: ProductColumns.price,
  );
```

## beak_backend: InMemoryAdapter and real handlers

Backend logic tests use worm's in-memory adapter instead of a database and drive
the Shelf handlers directly with `Request`/`Response`, asserting the status code
and the JSON body. The worm harness has one non-negotiable rule:
`tearDown(Worm.reset)`, because a double `Worm.initialize` throws. This suite also
wraps the in-memory adapter in a `LoggingAdapter`, so the same setup can count
queries for the reference-dedup and N+1 proofs.

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

Injecting `now` and `generateId` makes ids and timestamps deterministic, so a
test can assert the exact minted id and stamped time. For the query-count proofs,
assert against the `InMemoryQueryLogger` after a request.

## beak_frontend: pump the recording fake

Widget tests never hit a network. They pump an obers_ui widget with the suite's
`FakeDataSource`, which is a `BeakRecordingDataSource` wrapped around an
`InMemoryBeakDataSource`, then assert the rendered widgets, tap actions, and
check the emitted `BeakQuerySpec`.

```dart title="packages/beak_frontend/test/support/panel_fixtures.dart"
base class FakeDataSource extends BeakRecordingDataSource {
  FakeDataSource({
    Map<String, Map<Object, BeakRecord>>? records,
    List<BeakModel> models = const [],
  }) : this._(_storeFor(records ?? const {}, models));

  FakeDataSource._(this.store) : super(store);

  final InMemoryBeakDataSource store;
```

Because the calls are answered honestly, the fake catches what a canned-response
mock cannot: a filter that never reached the spec, a sort applied in the widget
instead of the query, a page-two fetch that returned page one. Seed with
`records`, keyed by table then id. A seeded row may carry a `relations` map: the
fixture unfolds it into whatever actually stores that relationship, a foreign key
or a pivot link, so an eager load resolves the way it would against a database.

```dart title="packages/beak_frontend/test/src/table/beak_data_table_test.dart"
  setUp(() {
    dataSource = FakeDataSource(
      records: {
        'notes': {
          for (var index = 1; index <= 3; index += 1) 'n$index': note(index),
        },
      },
    );
    controller = OiTableController(serverSidePagination: true);
  });
```

Assert round trips, not only pixels: `queryCalls`, `getOneCalls` and
`batchGetCalls` are what turn "it rendered the category name" into "and it cost
one query, not one per row". Extend the fake to make a single operation fail;
everything else keeps working. This is the
[fakes-over-mocks convention](conventions.md#tests-verify-behavior). Use golden
image tests only where a visual regression matters; prefer semantics and
behavior assertions.

## The examples are gated too

`examples/**` are workspace packages, so `melos run test` runs them and
`melos run coverage` grades them. They are not decoration: they are the
end-to-end proof that generated code compiles and the documented features still
work.

- `examples/store/test/widget_test.dart` boots the panel over an
  `InMemoryBeakDataSource` and asserts the coverage matrices: every column kind
  and every relationship kind Beak has must be demonstrated somewhere in the
  example. A new column kind nothing uses fails that test, which is the reminder
  to teach it.
- `examples/store/test/api_scenario.dart` is the API surface asserted once and
  run twice: `api_sqlite_test.dart` boots the real server on `sqlite::memory:`
  in the main gate, and `test/e2e/postgres_test.dart` runs the identical
  assertions against Postgres under the `e2e` tag.
- `examples/superdashboard/test/` holds the scale checks: 49 models, 17 of them
  navigable, every custom screen reachable, and schema parity between each model
  and the migration that creates its table.

When you add a feature to Beak, demonstrate it in an example and let one of
those tests hold it there.

## The coverage floor

The default floor is 85% line coverage per package. `melos run coverage`
(`tool/check_coverage.dart`) computes the number and fails the build below the
threshold:

```dart title="tool/check_coverage.dart"
const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  // A testing toolkit whose own tests are thin would be a poor advert.
  'beak_test': 90,
  'beak_storage_s3': 70,
  'quickstart': 50,
  'store': 70,
  'superdashboard': 85,
  'embedded': 85,
};
```

`beak_core` is pure and holds 100. `quickstart` and `store` hold a lower bar
deliberately: most of what an example declares is data, a screen's block tree or
a resource's actions, that a widget suite instantiates without executing line by
line. What has to work is checked directly instead, by the API scenario and by
the coverage matrices, which fail when a feature stops being demonstrated at
all. `beak_storage_s3` holds a lower bar for a different reason: a quarter of
the driver is request signing, retries and error mapping that only a real
endpoint reaches, and those lines are covered by its `test/e2e/` suite against
MinIO, which is outside this measurement because the main gate runs without
Docker.

Coverage is a floor, not a goal. Cover branches and error paths, not just the
happy one; a package at 90% with an untested failure mode is not done. And
remember the [coverage gotcha](index.md#the-coverage-gotcha): the tool reuses
existing `lcov.info` files, so delete stale reports before you gate:

```bash
rm -rf packages/*/coverage examples/*/coverage
melos run test && melos run coverage
```

## Continue reading

- [Testing guide](../guides/testing.md) the same patterns aimed at app authors.
- [Conventions](conventions.md) fakes over mocks and typed exceptions.
- [Code guardrails](code-guardrails.md) the rules tests help prove.
- [Contributing](index.md) the four-command gate the tests feed into.
