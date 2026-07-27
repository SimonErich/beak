---
title: Writing tests
description: Where tests live per package and the harness each one uses: pure units for core, an InMemoryAdapter for the backend, a fake data source for the panel, golden JSON, and the coverage floor.
---

# Writing tests

After this page you can add a test to any Beak package using the harness that
package expects: a pure unit for `beak_core`, worm's `InMemoryAdapter` for the
backend, a fake `BeakDataSource` for the panel, and a golden file to pin a wire
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

| Package                 | Runner          | Harness                                    |
| ----------------------- | --------------- | ------------------------------------------ |
| `beak_core`             | `dart test`     | pure units, zero I/O                       |
| `beak_backend` (logic)  | `dart test`     | worm `InMemoryAdapter`, drive Shelf directly |
| `beak_backend` (integ.) | `dart test`     | Postgres + MinIO via `melos run up`, tagged |
| `beak_frontend`         | `flutter test`  | `flutter_test`, a fake `BeakDataSource`     |

Integration tests that need Postgres or MinIO go in `test/integration/` and are
tagged (`@Tags(['integration'])`) so unit runs stay fast; the gate runs both.

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
});
```

The golden file is checked in, so an accidental change to the serialized shape
turns into a failing diff a reviewer sees. Pair it with a `fromJson` validation
group that asserts the parser rejects missing or wrongly typed keys; that is
where the "never leak `dynamic`" promise is actually enforced.

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
assert against the `InMemoryQueryLogger` after a request. Integration tests bring
the real services up with `melos run up`, run CRUD and uploads against Postgres
and MinIO, and tear down.

## beak_frontend: pump a fake data source

Widget tests never hit a network. They pump an obers_ui widget with an in-memory
`FakeDataSource` (a `BeakDataSource` that records calls and serves canned
records), then assert the rendered widgets, tap actions, and check the emitted
`BeakQuerySpec`.

```dart title="packages/beak_frontend/test/src/table/beak_data_table_test.dart"
Future<void> pumpTable(WidgetTester tester) async {
  await tester.pumpWidget(
    OiApp(
      theme: OiThemeData.light(),
      home: BeakDataTable(
        model: const NoteModel(),
        dataSource: dataSource,
        controller: controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

testWidgets('renders one column per table-visible column plus rows', (
  tester,
) async {
  await pumpTable(tester);
  expect(find.text('Title'), findsOneWidget);
  expect(find.text('Note 1'), findsOneWidget);
});
```

The fake lives in `test/support/panel_fixtures.dart` and is shared across the
panel suites. It records every `query`, `create`, `delete`, `attach`, and
`detach`, so a test can assert exactly what the widget asked the data source to
do, including optimistic and undo behavior. This is the
[fakes-over-mocks convention](conventions.md#tests-verify-behavior): the fake
actually stores and serves data, so it catches more than a mock returning canned
values. Use golden image tests only where a visual regression matters; prefer
semantics and behavior assertions.

## The coverage floor

The default floor is 85% line coverage per package, raised for the pure and
critical ones. `melos run coverage` (`tool/check_coverage.dart`) computes the
number and fails the build below the threshold:

```dart title="tool/check_coverage.dart"
const int defaultThresholdPct = 85;

const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  'store': 50,
  'store': 85,
};
```

Coverage is a floor, not a goal. Cover branches and error paths, not just the
happy one; a package at 90% with an untested failure mode is not done. And
remember the [coverage gotcha](index.md#the-coverage-gotcha): the tool reuses
existing `lcov.info` files, so delete stale reports before you gate:

```bash
rm -rf packages/*/coverage apps/*/coverage
melos run test && melos run coverage
```

## Continue reading

- [Testing guide](../guides/testing.md) the same patterns aimed at app authors.
- [Conventions](conventions.md) fakes over mocks and typed exceptions.
- [Code guardrails](code-guardrails.md) the rules tests help prove.
- [Contributing](index.md) the four-command gate the tests feed into.
