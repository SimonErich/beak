---
title: Writing tests
description: Add a test to any Beak package with the runner and harness it expects, and know which suites need Docker and what coverage floor applies.
type: guide
audience: [contributor]
status: stable
---

# Writing tests

You changed behavior and need a test that proves it. This page picks the runner, the fake and the folder for whichever package you touched, and lists the coverage floor the package has to clear. Every change is written test first: red, then green, then tidy.

## The loop

1. **Red.** Write the smallest test for the next behavior and run it. Confirm it fails for the right reason: a missing type or a wrong result, not a typo in the test.
2. **Green.** Write the least code that passes. Nothing speculative.
3. **Refactor.** Clean names, remove duplication, keep the test green.

Never weaken, skip or delete a test to get green, and never add an `// ignore:` to get past a lint. Fix the code. Many small tests beat a few broad ones, and every bug fix ships the regression test that would have caught it.

## At a glance

Tests mirror the source: `lib/src/query/beak_query_spec.dart` is tested in `test/src/query/beak_query_spec_test.dart`. Shared fixtures live in `test/support/`.

| Package | Runner | Harness | Line-coverage floor |
| --- | --- | --- | --- |
| `beak_core` | `dart test` | pure units, no I/O, golden JSON for wire types | 100% |
| `beak_test` | `dart test` | its own contract suite, run against itself | 90% |
| `beak_backend` | `dart test` | worm `InMemoryAdapter`, Shelf handlers driven directly | 90% |
| `beak_cli` | `dart test` | temp-directory projects, generate and compare | 85% |
| `beak_frontend` | `flutter test` | `flutter_test` and a recording fake data source | 85% |
| `beak` (umbrella) | `flutter test` | asserts what each library entry point exports | 85%, on no instrumented lines |
| `beak_storage_s3`, `beak_storage_ftp` | `dart test` | a fake transport injected into the driver | 85% |
| `beak_image`, `beak_serverpod`, `beak_serverpod_generator`, `beak_serverpod_server` | `dart test` | see each package's `test/` | 85% |
| `beak_serverpod_flutter` | `flutter test` | see its `test/` | 85% |
| `examples/*` | `flutter test` | the real panel, the real server on in-memory SQLite | 85%, `quickstart` 50% |
| the workspace root | `dart test` | the gate tooling itself, in `test/` | not measured |

A pure Dart package runs under `dart test`, a package that depends on Flutter under `flutter test`. `melos run test` picks the right one for each.

Pick the rung that answers your question with the least machinery:

| You are testing | Use | Look at |
| --- | --- | --- |
| A pure calculation | a plain `test` | `examples/clean_beak_config/test/shop_totals_test.dart` |
| Form or session logic over data | `BeakFormSession` over `InMemoryBeakDataSource` | `examples/clean_beak_config/test/order_form_test.dart` |
| A widget | `testWidgets` with a fake data source | `packages/beak_frontend/test/src/table/beak_data_table_test.dart` |
| An HTTP round trip, a policy or a rollback | the real server on an ephemeral port | `examples/clean_beak_config/test/shop_api_test.dart` |
| A migration | SQLite's own catalog, through `rawQuery` | `examples/clean_beak_config/test/shop_migration_test.dart` |
| A Postgres or MinIO difference | an `e2e` suite | [Service-backed suites](#service-backed-suites) |

## beak_core: pure units and golden JSON

`beak_core` is pure Dart, so its tests do no I/O and aim for full coverage. Any type that crosses the wire gets a golden test: encode, compare to a committed JSON file, decode back to an equal value. `BeakQuerySpec` is the headline case, because the frontend and the backend both speak it.

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

The golden file is checked in, so an accidental change to the serialized shape becomes a diff a reviewer sees. Pair it with tests that `fromJson` rejects a missing or wrongly typed key. That is where "never leak `dynamic`" is enforced.

## beak_test: the toolkit every suite shares

`packages/beak_test` holds the fakes, so nobody hand-rolls one. It reaches app authors as `package:beak/testing.dart`, which makes a bug in it a bug in everyone's tests.

| Symbol | What it is |
| --- | --- |
| `InMemoryBeakDataSource` | a complete `BeakDataSource` over maps: operators, nested filters, sorts, search, pagination, eager loads, soft deletes, aggregates |
| `BeakRecordingDataSource` | a decorator that records every call and forwards it unchanged; `queryCalls`, `getOneCalls`, `batchGetCalls` and the rest count round trips |
| `BeakRecordFactory`, `beakFakeRecord` | records derived from a model's own column metadata and rules, deterministic under a seed |
| `runBeakDataSourceContract` | the ten-method `BeakDataSource` interface as an executable definition of done |
| `expectSchemaParity`, `beakSchemaParityProblems` | model versus migration agreement, as an assertion and as a plain list of problems |

New `BeakDataSource` behavior goes into `runBeakDataSourceContract` first, so every implementation is held to it, including a third-party one. `InMemoryBeakDataSource` runs that contract against itself:

```dart title="packages/beak_test/test/src/in_memory_beak_data_source_test.dart"
--8<-- "packages/beak_test/test/src/in_memory_beak_data_source_test.dart:contract"
```

## beak_backend: in-memory database, real handlers

Backend logic tests use worm's in-memory adapter instead of a database and drive the Shelf handlers with `Request` and `Response`, asserting the status and the JSON body. The worm harness has one non-negotiable rule: `tearDown(Worm.reset)`, because a second `Worm.initialize` throws. This suite also wraps the adapter in a `LoggingAdapter`, so the same setup counts queries for the reference-deduplication and N+1 proofs.

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

Injecting `now` and `generateId` makes ids and timestamps deterministic, so a test can assert the exact minted id and stamped time. For query-count proofs, assert against the `InMemoryQueryLogger` after a request.

## A real server in a test

An example test can start the whole generated host on an ephemeral port over `sqlite::memory:`, migrate and seed it, and talk to it with the same `BeakClient` the panel uses. That is the level where a rollback, a replayed save or a policy denial is real rather than simulated. The shop keeps the setup in one helper:

```dart title="examples/clean_beak_config/test/support/shop_test_api.dart"
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
```

The `environment` map is the seam: the generated `beakHost` reads it instead of the process environment, so the test never touches the machine it runs on. Call `dispose()` in `tearDown`, or the next test inherits a bound port and a live `Worm`.

## beak_frontend: pump the recording fake

Widget tests never touch a network. They pump an obers_ui widget with the suite's `FakeDataSource`, a `BeakRecordingDataSource` wrapped around an `InMemoryBeakDataSource`, then assert the rendered widgets, tap actions and check the emitted `BeakQuerySpec`.

```dart title="packages/beak_frontend/test/support/panel_fixtures.dart"
base class FakeDataSource extends BeakRecordingDataSource {
  FakeDataSource({
    Map<String, Map<Object, BeakRecord>>? records,
    List<BeakModel> models = const [],
  }) : this._(_storeFor(records ?? const {}, models));

  FakeDataSource._(this.store) : super(store);

  final InMemoryBeakDataSource store;
```

Because the fake answers honestly, it catches what a canned-response mock cannot: a filter that never reached the spec, a sort applied in the widget instead of the query, a page-two fetch that returned page one. Seed it with `records`, keyed by table and then id. A seeded row may carry a `relations` map: the fixture unfolds it into whatever stores the relationship, a foreign key or a pivot link, so an eager load resolves as it would against a database.

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

Assert round trips, not only pixels. `queryCalls`, `getOneCalls` and `batchGetCalls` turn "it rendered the category name" into "and it cost one query, not one per row". To make a single operation fail, extend the fake and override that one method. Use golden image tests only where a visual regression is the point, and prefer semantics and behavior assertions.

## Sealed hierarchies get a matrix test

Dart cannot list the subtypes of a sealed class at runtime. When the docs or a feature promise coverage of every variant, a test switches over the hierarchy with no default branch. Adding a variant stops the file compiling until someone adds an arm, and the arm forces the fixture to declare one. The showcase does this for every column kind:

```dart
--8<-- "examples/showcase/test/column_kind_matrix_test.dart:kindOf"
```

The same shape covers block types and relation kinds in `examples/showcase/test`.

## Service-backed suites

A suite that needs Postgres or MinIO goes in `test/e2e/`, opens with `@Tags(['e2e'])` and is excluded from `melos run test`. `melos run test-e2e` runs every `test/e2e` directory after `melos run up`. Tag a suite `e2e` for cost too: three CLI suites need only SQLite but run a real `flutter pub get`, which is too slow for the main gate.

| Suite | Needs | With the service down |
| --- | --- | --- |
| `packages/beak_backend/test/e2e/postgres_integration_test.dart` | Postgres | skips with a message |
| `packages/beak_backend/test/e2e/upload_s3_integration_test.dart` | MinIO | skips with a message |
| `packages/beak_storage_s3/test/e2e/s3_minio_integration_test.dart` | MinIO | skips with a message |
| `packages/beak_cli/test/e2e/round_trip_test.dart`, `postgres_introspection_test.dart` | Postgres | skips with a message |
| `packages/beak_cli/test/e2e/adopt_existing_schema_test.dart`, `evolvability_test.dart`, `init_embedded_test.dart` | Flutter tooling, SQLite | none needed, but slow |

[Dev infrastructure](dev-infrastructure.md) starts the stack and explains the ports.

## The coverage floors

`melos run coverage` runs `tool/check_coverage.dart`. It reads each package's `coverage/lcov.info`, ignores generated `*.g.dart` and `*.beak.dart` files, and fails a package below its floor. The default is 85%. These packages have another:

```dart title="tool/check_coverage.dart"
const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  'beak_test': 90,
  'quickstart': 50,
};
```

`quickstart` is low because it must stay byte-identical to what `beak create` writes, so it carries only the one boot test the scaffold ships. Adding tests there would make the example drift from the scaffold it documents. Do not lower a floor or exclude new logic to pass the gate. Add the test.

## Rules and limits

- **The gate reads what is on disk.** Pure Dart packages keep an old `lcov.info` and the check reuses it. Delete `packages/*/coverage` and `examples/*/coverage` before `melos run test` if you want fresh numbers.
- **One fresh adapter per backend test.** Build the in-memory database in `setUp`, register the schema up front, call `tearDown(Worm.reset)`. Reach for `SqliteAdapter.memory()` only when a test needs raw SQL.
- **Seed anything random.** `Worm.seedRandom(42)` and an injected `now` keep ids and timestamps stable.
- **The umbrella reports no lines.** `packages/beak` re-exports and instruments nothing, so its floor passes on zero lines and its tests guard the export lists instead.
- **`examples/serverpod` is outside melos.** Its tests run from the workspace, as its README describes, and by the `serverpod-example` and `serverpod-admin` CI jobs, not by `melos run test`. The server's `test/integration` suites start an embedded Postgres, and they need `config/passwords.yaml` copied from the committed example first.
- **Fakes must stay honest.** A fake that returns what the test wants proves the test. Extend `InMemoryBeakDataSource` when a behavior is missing, and add it to the contract.

## Verify it

Run the test you just wrote on its own, in its package:

```bash
cd packages/beak_core
dart test test/src/query/beak_query_spec_test.dart
```

```text
00:00 +30: All tests passed!
```

A Flutter package takes `flutter test` and the same path:

```bash
cd packages/beak_frontend
flutter test test/src/table/beak_data_table_test.dart
```

```text
00:02 +20: All tests passed!
```

Then check the floors. Delete stale reports, run the tests, run the gate:

```bash
rm -rf packages/*/coverage examples/*/coverage
melos run test
melos run coverage
```

```text
OK   beak_core: 100.0% line coverage (threshold 100%, 3839/3839 lines)
OK   beak_backend: 94.8% line coverage (threshold 90%, 2872/3030 lines)
```

The counts change with the code. A package below its floor prints `FAIL` with the same fields and the run exits non-zero.

## Reference

| File | Role |
| --- | --- |
| `tool/check_coverage.dart` | the floors, the lcov reader, the generated-file exclusion |
| `test/check_coverage_test.dart` | tests for the coverage gate itself |
| `packages/beak_test/lib/src/` | the fakes, the factory, the contract and the parity assertion |
| `packages/beak_backend/dart_test.yaml`, `packages/beak_storage_s3/dart_test.yaml` | declare the `e2e` tag with a doubled timeout |
| `melos.yaml` | `test`, `test-dart`, `test-flutter`, `test-e2e`, `test-root`, `test-worm`, `coverage` |

## Continue reading

- [Dev infrastructure](dev-infrastructure.md) start Postgres and MinIO for the e2e suites.
- [Testing](../shipping/testing.md) the same fakes, aimed at app authors.
- [Conventions](conventions.md) fakes over mocks, typed exceptions, regenerating.
- [Code guardrails](code-guardrails.md) the rules tests help prove.
