# beak_test

The testing toolkit of Beak: a complete in-memory `BeakDataSource`, a wrapper
that counts round trips, fixtures derived from your model metadata, an
executable contract every data source must pass, and a check that your models
and your migrations agree.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter.

## When you depend on it

An app gets all of this as `package:beak/testing.dart`, from the
[`beak`](https://github.com/SimonErich/beak/tree/main/packages/beak) umbrella.
Depend on `beak_test` directly when you write a `BeakDataSource` of your own, in
a pure Dart package that cannot use the umbrella, and want to run the contract
against it. It depends on `package:test`, on purpose: the contract declares real
groups and expectations.

## Test against a source that honors the query

A fake that ignores the query spec lets a green widget test prove nothing about
filtering, sorting or paging. `InMemoryBeakDataSource` applies all of it, and
`BeakRecordingDataSource` wraps any source and records every call, so a test can
also say how many round trips a screen costs. Run this in a project created with
`beak create`:

```dart
import 'package:beak/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acme_admin/beak/registry.g.dart';
import 'package:acme_admin/resources/notes/models/note.dart';

void main() {
  test('a list query is one round trip and honors the filter', () async {
    final source = BeakRecordingDataSource(
      InMemoryBeakDataSource(registry: buildBeakRegistry())
        ..seed(const NoteModel(), [
          const NoteModel().record([
            NoteModel.id.to('n-1'),
            NoteModel.title.to('Release notes'),
            NoteModel.pinned.to(true),
          ]),
          const NoteModel().record([
            NoteModel.id.to('n-2'),
            NoteModel.title.to('Groceries'),
            NoteModel.pinned.to(false),
          ]),
        ]),
    );

    final page = await source.query(
      const NoteModel().query(filter: NoteModel.pinned.eq(true)),
    );

    expect(page.items.map(NoteModel.title.require), ['Release notes']);
    expect(source.queryCalls, hasLength(1));
  });
}
```

The record is built from generated field references, so no column name appears
as a string. The scaffold's `test/widget_test.dart` shows the same source under a
panel: `BeakApp(dataSource: source)` renders the empty states until you seed it.

## Prove a data source belongs

`runBeakDataSourceContract` is the definition of done for `BeakDataSource`. It
pins the edges that only bite in production: `getOne` returns `null` instead of
throwing, `update` throws when the row is gone, `aggregate` returns `0` over an
empty set, and a soft-deleted row hides from `query` unless the spec asks for it.
The contract cannot know how your source is populated, so you supply `create` and
`seed`. This is how `beak_backend` holds `WormDataSource` to it:

```dart title="packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart"
  runBeakDataSourceContract(
    'WormDataSource',
    registry: createApiRegistry(),
    model: const NoteModel(),
    create: () async {
      adapter = await createApiTestDatabase();
      return WormDataSource(createApiRegistry(), adapter: adapter);
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
```

## What is in it

| Symbol | What it is for |
| --- | --- |
| `InMemoryBeakDataSource` | A `BeakDataSource` over maps. It honors filters (including dotted relation paths and relation filters), sorts, search, paging, eager relation loads, soft deletes, has-many and many-to-many attach and detach, and aggregates. `seed(model, records)` and `seedPivot(...)` fill it; `rowsOf(table)` reads what a write persisted; `now` and `generateId` pin timestamps and ids. |
| `BeakRecordingDataSource` | Forwards every call to an inner source and records it: `queryCalls`, `getOneCalls`, `batchGetCalls`, `createCalls`, `updateCalls`, `deleteCalls`, `restoreCalls`, `attachCalls`, `detachCalls`, `aggregateCalls`, and `clearRecordedCalls()`. It is a `base class`, so a subclass can make one operation fail. |
| `runBeakDataSourceContract` | The executable contract, described above. |
| `BeakRecordFactory`, `beakFakeRecord` | Records derived from a model's column metadata and rules, so a fixture cannot drift from `BeakMaxLength(60)`. Deterministic under a seed; `overrides` take a value by column key. Soft-delete markers are left unset, so a fixture is not born deleted. |
| `expectSchemaParity` | Asserts that every model has a table with the columns it declares, plus the foreign key of every belongs-to. You supply the columns your stack can introspect. |
| `expectNoOrphanTables` | The other direction: a table no model claims. |
| `beakSchemaParityProblems` | The pure half of the parity check. It returns the disagreements as a list of strings instead of failing, for a tool that is not a test. |

## Limits

- **`BeakDataSource` only.** `InMemoryBeakDataSource` and
  `BeakRecordingDataSource` implement the ten `BeakDataSource` methods and
  nothing else: not `BeakCommitDataSource`, `BeakExportDataSource`,
  `BeakEditDataSource` or `BeakCapabilityDataSource`. A test of graph-commit
  behavior needs the real backend (`beak_backend` with an in-memory worm
  adapter).
- **Not a database.** It does not enforce primary keys, foreign keys or unique
  indexes, and it runs no validation rules or model behavior. Those run on the
  server.
- **Beak's own tables count as orphans.** `expectNoOrphanTables` skips the common
  migration bookkeeping tables, not `_beak_commit_receipts` or `_beak_outbox`. In
  a project that ran Beak's migrations, pass both in `ignoreTables`.
- **The contract has no relation cases.** It does not cover relation loads or
  attach and detach.

## Continue reading

- [Testing](https://simonerich.github.io/beak/shipping/testing/): how a Beak project tests panel, server and data.
- [Writing tests](https://simonerich.github.io/beak/contributing/writing-tests/): the conventions in this repository.
- [The data source seam](https://simonerich.github.io/beak/architecture/data-source-seam/): what `BeakDataSource` promises and who implements it.
- [Custom data sources](https://simonerich.github.io/beak/extending/custom-data-sources/): writing one and running the contract.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
