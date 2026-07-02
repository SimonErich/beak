---
title: SQLite
description: Construct, tune, and debug the worm_sqlite adapter for embedded SQLite databases.
---

`worm_sqlite` implements worm's adapter contract on an embedded SQLite database through the `sqlite3` package. This page covers construction, the capability profile, dialect behavior, and the single-connection rules. It builds on [how drivers work](./how-drivers-work.md).

## Install

```yaml title="pubspec.yaml"
dependencies:
  worm:
    path: ../worm
  worm_sqlite:
    path: ../worm_sqlite
```

The driver packages are monorepo-internal today (`publish_to: none`), so you depend on them by path. The `sqlite3` client (`^2.4.0`) comes in transitively.

## Construct

`SqliteAdapter` has one constructor and two factories:

```dart
import 'package:worm_sqlite/worm_sqlite.dart';

// Fresh in-memory database. Ideal for tests.
final adapter = SqliteAdapter.memory();

// Open or create a file-backed database at a path.
final adapter = SqliteAdapter.open('app.db');

// Wrap an already-open sqlite3 CommonDatabase.
final adapter = SqliteAdapter(database, compiler: const SqliteCompiler());
```

Register it under a connection name. `Worm.initialize` calls `connect()` on every adapter for you:

```dart
await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': SqliteAdapter.open('app.db')},
);
```

`connect()` applies three pragmas: `journal_mode = WAL`, `foreign_keys = ON`, and `synchronous = NORMAL`. WAL lets readers run without blocking writers (a no-op for in-memory databases), and `synchronous = NORMAL` is the safe, fast companion to WAL. `disconnect()` clears the statement cache and disposes the underlying database.

## Capability profile

The adapter declares this `AdapterCapabilities` profile (shared with its transaction adapter):

| Flag | Value |
| --- | --- |
| `supportsTransactions` | `true` |
| `supportsSavepoints` | `true` |
| `supportsStreaming` | `true` |
| `supportsRawQuery` | `true` |
| `supportsReturning` | `false` |
| `supportsJoins` | `true` |
| `supportsPreparedStatements` | `false` |
| `supportsPartialIndexes` | `false` |
| `supportsAggregations` | `true` |
| `supportsSchemaIntrospection` | `true` |
| `supportsExplain` | `true` |

`supportsReturning` is `false` because SQLite writes do not read database-computed values back. `insert()` and `insertMany()` still return rows: they echo the values you supplied, projected to the `returning` columns when you set them. Note that the declared profile leaves `supportsPreparedStatements` off even though the adapter caches prepared statements internally; the flag only answers capability queries, it does not change execution.

## Dialect notes

- Identifiers are double-quoted (`"users"`), with embedded quotes doubled.
- Placeholders are positional `?` markers, always bound through prepared statements.
- SQLite binds only `int`, `double`, `String`, `Uint8List`, and `null`. The adapter normalizes `bool` to `0`/`1` and `DateTime` to ISO-8601 text.
- `inList`/`notInList` values chunk at `kSqliteInListChunkSize` (900) per statement, staying under SQLite's 999-parameter limit. Chunks recombine with `OR` (or `AND` for `notInList`).
- `insertMany` compiles to a list of chunked multi-row `INSERT` statements instead of one statement per row.
- `SchemaOperation.alter` is not implemented in the compiler and throws `QueryException`.

## Error mapping

`SqliteErrorMapper` wraps every operation. It reads the extended result code from `SqliteException`:

| Native code | Meaning | Worm exception |
| --- | --- | --- |
| `2067` | UNIQUE constraint | `UniqueConstraintException` |
| `1555` | PRIMARY KEY constraint | `UniqueConstraintException` |
| `787` | FOREIGN KEY constraint | `ForeignKeyException` |
| any other `SqliteException` | | `QueryException` |
| any other thrown object | | `QueryException` |

Pre-existing `WormException`s pass through unwrapped. See [exceptions](../reference/exceptions.md) for the full hierarchy.

## Transactions and savepoints

`transaction()` runs your callback inside `BEGIN ... COMMIT` and hands it a transaction-scoped adapter. A throw rolls back and rethrows your original exception unchanged. Nested `transaction()` calls open savepoints named `worm_sp_1`, `worm_sp_2`, and so on; an inner failure rolls back to its savepoint only.

SQLite is single-connection: there is no pool, and a transaction cannot service overlapping queries from other callers. Keep transaction callbacks sequential.

## EXPLAIN

`explain()` runs `EXPLAIN QUERY PLAN` over the compiled SELECT. The result's `usesIndex` is `true` when the plan contains `USING INDEX` or `USING COVERING INDEX`; `raw` holds the joined plan detail lines and `scannedTables` lists the queried table.

## Prepared-statement cache

Every descriptor-compiled statement runs through `SqlitePreparedCache`, a strict LRU keyed by SQL text, holding up to 128 statements (`maxSize`). `rawQuery` and `rawExecute` bypass it. Inspect it via the adapter:

```dart
final cache = adapter.preparedStatementCache;
print('${cache.hitCount} hits, ${cache.missCount} misses');
print('miss rate: ${cache.missRate}, cached: ${cache.length}');
```

`clear()` disposes every cached statement and resets the counters. The adapter calls it automatically after any DDL (a recreated table can invalidate statements that referenced it) and on `disconnect()`.

## Platforms

The default barrel imports the ffi-backed `sqlite3` library, so the adapter runs on server-side Dart and Flutter native (mobile and desktop). It does not run on Flutter Web. The main constructor accepts any `CommonDatabase`, so a WASM-backed database could in principle be injected, but the shipped factories are native-only.

## Contract tests

The adapter passes worm's shared conformance suite, and you can run the same suite against your own setup:

```dart title="test/sqlite_contract_test.dart"
import 'package:worm/testing/adapter_contract.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  runAdapterContractTests(
    name: 'SqliteAdapter contract',
    capabilities: const AdapterCapabilities(
      supportsTransactions: true,
      supportsSavepoints: true,
      supportsStreaming: true,
      supportsRawQuery: true,
      supportsJoins: true,
      supportsAggregations: true,
      supportsSchemaIntrospection: true,
      supportsExplain: true,
    ),
    adapterFactory: SqliteAdapter.memory,
  );
}
```

No server, no environment variables: SQLite runs in-process.

## Gotchas

- One connection, no pool. Overlapping queries inside a transaction are not supported; worm's eager loading already serializes inside transactions.
- `insert()` echoes your supplied values. Database-computed defaults (other than what you passed) are not read back.
- DDL clears the prepared-statement cache, so a migration-heavy test run shows a higher miss rate by design.
- `stream()` is buffered: it selects all rows first, then yields them one by one.
- `IN` lists chunk at 900 values; huge lists compile into several `OR`-combined groups within one statement.
- Altering tables through `SchemaOperation.alter` throws `QueryException`; the compiler does not implement it.

## Continue reading

- [Choosing a database](./choosing-a-database.mdx): the full capability matrix across all five adapters.
- [Performance](../guides/performance.md): what the statement cache and `explain()` buy you in practice.
- [Testing](../guides/testing.md): `SqliteAdapter.memory()` as a fast test double with real SQL semantics.
