---
title: In-memory
description: The bundled InMemoryAdapter, a full worm backend that lives entirely in RAM.
---

`InMemoryAdapter` is worm's built-in backend: all worms, no dirt. It ships inside the core package, needs zero setup, and passes the same adapter contract suite as the real drivers. It's the default driver id in `ConnectionConfig` and the fastest way to run tests. This page builds on [how drivers work](./how-drivers-work.md).

## Install

Nothing to install. The adapter is exported from `package:worm/worm.dart`, so any project that depends on `worm` already has it. It is also the default: `ConnectionConfig.driver` defaults to `'inMemory'`.

## Construct

```dart
import 'package:worm/worm.dart';

Future<void> main() async {
  await Worm.initialize(
    config: const WormConfig(),
    adapters: {'default': InMemoryAdapter()},
  );
}
```

`InMemoryAdapter()` creates a fresh, empty store. You can override the declared capability matrix for testing gate behavior:

```dart
final adapter = InMemoryAdapter(
  capabilities: const AdapterCapabilities(supportsTransactions: true),
);
```

Create tables through migrations as usual, or directly with a descriptor:

```dart
await adapter.executeSchema(const SchemaDescriptor.createTable(
  table: 'users',
  columns: [
    SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
    SchemaColumn(name: 'name', type: ColumnType.text),
  ],
));
```

## Capability profile

The default profile declares seven of the 11 flags:

| Flag | Default | Notes |
| --- | --- | --- |
| `supportsTransactions` | true | snapshot and restore |
| `supportsSavepoints` | true | nested `transaction()` calls over the shared store |
| `supportsStreaming` | true | materializes the rows, then yields them |
| `supportsReturning` | true | echoes the inserted row, projected to `returning` columns |
| `supportsAggregations` | true | count, sum, avg, min, max |
| `supportsSchemaIntrospection` | true | returns table names with declared columns |
| `supportsExplain` | true | synthetic plan, see below |
| `supportsRawQuery` | false | no native query language |
| `supportsJoins` | false | |
| `supportsPreparedStatements` | false | |
| `supportsPartialIndexes` | false | |

`adapterType` is `AdapterType.inMemory`, so neither the `.sql()` nor the `.mongo()` query gate opens. Both throw `AdapterMismatchException`.

## How it stores and filters data

The adapter wraps an `InMemoryStore`: a map of table name to `List<Map<String, Object?>>` rows, plus a schema map of declared columns. A `QueryDescriptor` runs through a fixed pipeline: filter, sort, project, optionally deduplicate (`distinct`), then paginate.

Filtering delegates to the shared `PredicateEvaluator`, the same class third-party in-memory-style adapters can reuse for consistent semantics:

- `like` and `notLike` translate the pattern to an anchored regex (`%` becomes `.*`, `_` becomes `.`); `ilike` is the case-insensitive variant.
- `between` and `notBetween` are inclusive on both bounds.
- Comparisons use NULLS-FIRST ordering: two nulls are equal, null sorts before any value, everything else goes through `Comparable.compare`.
- `whereExists` subqueries resolve against the same store.
- Column-to-column predicates support only `eq`, `neq`, `gt`, `gte`, `lt`, `lte`.

## Transactions are snapshots

`transaction()` takes a deep-cloned snapshot of the entire store, runs your callback against the shared store, and restores the snapshot if the callback throws:

```dart
await Worm.transaction((txn) async {
  await user.save();
  throw StateError('boom'); // store restored, nothing persisted
});
```

Nested `transaction()` calls snapshot again, which gives you savepoint semantics: an inner rollback restores only the inner snapshot, and the outer transaction continues.

## Lifecycle: disconnect keeps, close wipes

| Method | Connection flag | Data |
| --- | --- | --- |
| `connect()` | sets `isConnected` to true | untouched |
| `disconnect()` | sets `isConnected` to false | kept |
| `close()` | sets `isConnected` to false | discarded, every table and schema cleared |

There is no pooling: the adapter is a single in-process object. `Worm.initialize` calls `connect()` for you; `Worm.reset()` calls `disconnect()`.

## Errors it throws

There is no native driver underneath, so nothing gets mapped. The adapter and store throw directly:

| Condition | Thrown |
| --- | --- |
| `rawQuery` or `rawExecute` | `UnsupportedOperationException` |
| `executeSchema` with `SchemaOperation.alter` | `UnsupportedOperationException` |
| `whereRaw` predicate reaching the evaluator | `UnsupportedOperationException` |
| Querying or truncating a table that doesn't exist | `StateError` |
| Creating a table that already exists (without `ifNotExists`) | `StateError` |
| `sum`, `avg`, `min`, `max` without a column | `StateError` |
| Comparing values that aren't `Comparable` | `StateError` |

`executeSchema` with `SchemaOperation.createIndex` is a silent no-op: the store doesn't model indexes, but stays compatible with index-aware migrations.

## EXPLAIN

The adapter mixes in `ExplainCapable` and always returns the same synthetic `ExplainResult`: `usesIndex: true` with the raw text `InMemoryAdapter: synthetic plan (always indexed)`. That keeps strictness features like the missing-index warner quiet in tests. Don't use it to reason about real query plans.

## Diagnostics

- `adapter.store` exposes the underlying `InMemoryStore`: `tableNames`, `schemas`, `hasTable`, `columnsOf`, `rowsOf` (the live, mutable row list), `truncate`, `clear`, and `snapshot()`/`restore()`.
- `adapter.isConnected` reports lifecycle state.
- `compileToString` renders a generic SQL string for a `QueryDescriptor` and short summary strings for write and schema descriptors, so query logging still shows something readable.

## Gotchas

- `close()` wipes all data; `disconnect()` keeps it. Pick the right one in test teardown.
- Data is per-adapter-instance and per-isolate. Two `InMemoryAdapter` instances share nothing.
- Transaction snapshots deep-clone the whole store. With large seeded datasets, transaction-heavy tests pay a copy cost per transaction.
- `stream()` materializes all matching rows first. Fine for tests, but it won't exercise real cursor behavior.
- Joins are unsupported, so query paths that require `.sql()` features can't be tested here; use `SqliteAdapter.memory()` from `worm_sqlite` instead.
- The synthetic EXPLAIN plan always claims an index. Index-related strictness checks pass vacuously.

## Contract test

The adapter validates against the shared conformance suite, the same one every real driver runs. The kit lives at `package:worm/testing/adapter_contract.dart` and is deliberately not exported from the main barrel:

```dart title="test/in_memory_contract_test.dart"
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';

void main() {
  runAdapterContractTests(
    adapterFactory: InMemoryAdapter.new,
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsStreaming: true,
      supportsReturning: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    name: 'InMemoryAdapter contract',
  );
}
```

## Continue reading

- [Testing](../guides/testing.md): the full test playbook built on this adapter.
- [Writing a database driver](../contributing/writing-a-database-driver.md): reuse `PredicateEvaluator` and the contract kit in your own adapter.
- [Choosing a database](./choosing-a-database.mdx): when to graduate to a real backend.
