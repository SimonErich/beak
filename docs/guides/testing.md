---
title: Testing
description: The test seams Beak is built on: a fake data source for the panel, an in-memory worm database for the backend, golden JSON for the query wire format, and the coverage gate.
---

# Testing

Beak was built test-first, so every layer already has a seam you can push a fake
through. After this page you can test a resource end to end without a live server:
render the panel against an in-memory data source, drive the generated API over an
in-memory worm database, pin the query wire format with a golden file, and satisfy
the coverage gate.

## The four seams

There is one seam per layer, and each one lets a test replace the layer below it
with something fast and deterministic.

| Seam | Where | What it replaces | Used for |
| --- | --- | --- | --- |
| A fake `BeakDataSource` | `beak_frontend` widget tests | the network | render the panel and forms, assert the emitted `BeakQuerySpec` and writes |
| worm `InMemoryAdapter` | `beak_backend` logic tests | Postgres | drive the real Shelf handlers over a real database, in memory |
| Golden `BeakQuerySpec` JSON | `beak_core` unit tests | nothing (pins the contract) | catch any accidental change to the wire format |
| `InMemoryTokenSessionStore`, `LoggingAdapter` | both | sessions, query logs | assert auth flows and query counts |

The rules behind all of them live in the
[tdd-loop skill](../contributing/writing-tests.md): write the smallest failing
test first, never weaken a test to go green, and never hit a real network in a
widget test.

## Frontend: inject a fake data source into the panel

`BeakPanel` and `BeakDataForm` both take an optional `dataSource`. Pass one and
the whole panel runs against it, no HTTP client in sight. The frontend flow is
Widget then ViewModel then Repository then DataSource, so swapping the data source
swaps the bottom of the whole stack.

The fixture the frontend suites use is a `base class` that implements
`BeakDataSource`, serves canned records, and records every call it receives so a
test can assert on them.

```dart title="packages/beak_frontend/test/support/panel_fixtures.dart"
base class FakeDataSource implements BeakDataSource {
  FakeDataSource({Map<String, Map<Object, BeakRecord>>? records})
    : _recordsByTable = records ?? {};

  /// Every `query` invocation.
  final List<BeakQuerySpec> queryCalls = [];

  /// Every `create` invocation, as `(table, data)` pairs.
  final List<(String, BeakRecord)> createCalls = [];

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
    queryCalls.add(spec);
    final records = (_recordsByTable[spec.table] ?? {}).values.toList();
    return BeakPage(
      items: records,
      total: records.length,
      page: spec.pagination.page,
      perPage: spec.pagination.perPage,
    );
  }

  // create/update/delete/batchGet/attach/detach/aggregate record their calls too.
}
```

Hand that fake to `BeakPanel` and pump the widget. The panel builds its shell,
router, and generated pages exactly as it would in production.

```dart title="packages/beak_frontend/test/src/panel/beak_panel_test.dart"
const config = BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: 'http://localhost:8080',
  resources: [
    BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.notebook)),
    BeakResource(
      model: LabelModel(),
      icon: BeakIconToken(OiIcons.tag),
      label: 'Tags',
    ),
  ],
);

await tester.pumpWidget(
  BeakPanel(config: config, dataSource: FakeDataSource()),
);
```

The same seam works on a single form. Give `BeakDataForm` the fake, fill a field,
tap the submit button, then read the recorded call back out to prove the widget
sent the right typed record.

```dart title="packages/beak_frontend/test/src/form/beak_data_form_test.dart"
await tester.enterText(find.byType(EditableText).first, 'Fresh note');
await tester.pumpAndSettle();
await tester.tap(find.text('Create'));
await tester.pumpAndSettle();

expect(dataSource.createCalls, hasLength(1));
final (String table, BeakRecord sent) = dataSource.createCalls.single;
expect(table, 'notes');
expect(sent['title'], const BeakStringValue('Fresh note'));
```

!!! note "What just happened"
    - The form ran its client-side validation (the column rules mirror the server)
      before it ever called the data source.
    - A valid submit called `create` with a typed `BeakRecord`, not a
      `Map<String, dynamic>`.
    - The test read the emitted call straight off the fake, so it asserts behavior
      with no network and no mocking framework.

To test a failure path, subclass the fake and throw a typed exception from the one
method under test. The form maps a `BeakValidationException` back onto the
offending fields and surfaces anything else as a global error.

```dart title="packages/beak_frontend/test/src/form/beak_data_form_test.dart"
final class _Rejecting extends FakeDataSource {
  @override
  Future<BeakRecord> create(String table, BeakRecord data) async {
    throw const BeakValidationException(
      'Validation failed.',
      fieldErrors: {
        'title': ['Already taken.'],
      },
    );
  }
}
```

## Backend: drive the real handlers over an in-memory database

Backend logic tests do not mock the service or the data source. They stand up the
real `beakApiRouter` over a `WormDataSource` backed by worm's `InMemoryAdapter`,
then send real Shelf `Request`s through it. You get the whole
Handler then Service then DataSource stack, exercised in memory.

The harness connects a fresh adapter, creates the schema, and initializes worm.
Pair it with `tearDown(Worm.reset)`: worm throws on a double-init, so the reset is
mandatory, and a fresh adapter per test keeps them isolated.

```dart title="packages/beak_backend/test/support/api_models.dart"
Future<InMemoryAdapter> createApiTestDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  for (final descriptor in apiSchema) {
    await adapter.executeSchema(descriptor);
  }
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
  );
  return adapter;
}
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

  expect(response.statusCode, 201);
  final values = valuesOf(await bodyOf(response));
  expect(values['id'], 'minted-1');
  expect(values['title'], 'Grocery run');
});
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

!!! question "What this skipped"
    Integration tests that need real Postgres and MinIO live in `test/integration/`
    and are tagged so the fast unit run skips them. Bring the services up with
    `melos run up` first. See [The data source seam](../backend/the-data-source-seam.md)
    for how `WormDataSource` sits behind the interface both runs share.

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
});
```

The file it checks against is committed, so a diff in review shows the format change
in plain sight.

```json title="packages/beak_core/test/golden/rich_query_spec.json"
{
  "table": "posts",
  "filter": {
    "type": "and",
    "filters": [
      {
        "type": "field",
        "column": "status",
        "operator": "eq",
        "value": "active"
      }
    ]
  },
  "sorts": [
    {
      "column": "created_at",
      "descending": true
    }
  ]
}
```

For the round-trip property itself, a single test encodes, decodes, and re-encodes a
handful of specs and asserts stability. Timestamps become tagged objects on the wire,
so decoding never mistakes one for a plain string.

```dart title="packages/beak_core/test/src/query/beak_query_spec_test.dart"
test('encode → decode → encode is stable across representative specs', () {
  final specs = <BeakQuerySpec>[
    const BeakQuerySpec(table: 'products'),
    const BeakQuerySpec(table: 'posts', withTrashed: true),
    const BeakQuerySpec(table: 'users').searching('ada', [name]),
    richSpec(),
  ];
  for (final spec in specs) {
    final encoded = jsonEncode(spec.toJson());
    final decoded = switch (jsonDecode(encoded)) {
      final Map<String, Object?> map => BeakQuerySpec.fromJson(map),
      final Object? other => fail('expected a JSON object, got $other'),
    };
    expect(decoded, spec);
    expect(jsonEncode(decoded.toJson()), encoded);
  }
});
```

## Where tests live and how to run them

Tests mirror `lib/src/...` under `test/...`. Pure-Dart packages
(`beak_core`, `beak_backend`, `beak_cli`) run with `dart test`; the Flutter package
(`beak_frontend`) runs with `flutter test`. One command runs the lot:

```bash
melos run test
```

That fans out into the per-toolchain scripts, so you can run just one while you work:

```bash
melos exec --scope="beak_core" -- dart test        # one Dart package
melos exec --scope="beak_frontend" -- flutter test  # the Flutter panel
```

## The coverage gate

Coverage is a gate, not a vanity number. `melos run coverage` computes line coverage
per package and fails if any package is under its floor. The default is 85%, with
overrides for the packages that can do better.

```dart title="tool/check_coverage.dart"
/// Default line-coverage threshold (in percent) for gated packages.
const int defaultThresholdPct = 85;

/// Per-package threshold overrides, keyed by package directory name.
const Map<String, int> thresholdOverridesPct = {
  'beak_core': 100,
  'beak_backend': 90,
  'beak_frontend': 85,
  'beak_cli': 85,
  'store': 50,
  'store': 85,
};
```

`beak_core` is pure Dart with no I/O, so it holds at 100%. The floor is there to keep
you honest about branches and error paths, not just happy paths: a package at 90%
coverage with an untested failure mode has not really passed.

!!! tip "Run coverage on a clean tree"
    `melos run coverage` reads the lcov report each package's test run produced, so
    run `melos run test` first (or delete stale `packages/*/coverage` directories) to
    make sure it grades this run, not the last one.

## Continue reading

- [Writing tests](../contributing/writing-tests.md) the red, green, refactor loop and
  the per-package conventions.
- [Results and errors](../concepts/results-and-errors.md) the exception family your
  backend tests assert on.
- [How data flows](../concepts/how-data-flows.md) the `BeakQuerySpec` the golden test
  pins.
- [The data source seam](../backend/the-data-source-seam.md) why the same
  `BeakDataSource` interface serves both the fake and the real database.
