---
title: MySQL
description: Construct, pool, and secure the worm_mysql adapter, including its TLS certificate default.
---

`worm_mysql` implements worm's adapter contract on MySQL and MariaDB through the `mysql_client_plus` package. This page covers construction, the TLS certificate default you should know about, dialect emulations, and error mapping. It builds on [how drivers work](./how-drivers-work.md).

## Install

```yaml title="pubspec.yaml"
dependencies:
  worm:
    path: ../worm
  worm_mysql:
    path: ../worm_mysql
```

The driver packages are monorepo-internal today (`publish_to: none`), so you depend on them by path. The `mysql_client_plus` client (`^0.1.3`) comes in transitively.

## Construct

Two factories build the pool; the adapter takes it from there:

```dart
import 'package:worm_mysql/worm_mysql.dart';

// From worm's ConnectionConfig.
final pool = MysqlConnectionPool.fromConfig(const ConnectionConfig(
  driver: 'mysql',
  host: 'localhost',
  port: 3306,
  database: 'app',
  username: 'app',
  password: 'secret',
  poolSize: 4,
));

// Or from a URL.
final pool = MysqlConnectionPool.fromUri(
  'mysql://app:secret@localhost:3306/app',
  maxConnections: 5,
);

final adapter = MysqlAdapter(pool: pool);

await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
);
```

`MysqlAdapter` takes a required `pool`, an optional `compiler` (defaults to `const MysqlCompiler()`), and an optional `preparedStatementCache` for churn diagnostics. `connect()` is a no-op (the pool is lazy); `disconnect()` closes the pool. A `port` of `0` in `ConnectionConfig` resolves to `3306`.

## TLS and certificates

`fromUri` enables TLS when the URL carries `?ssl=true` or `?secure=true` (also accepted: `1`).

:::caution[Permissive certificate default]
When `fromUri` enables TLS and you pass no `onBadCertificate` callback, the pool installs a permissive one that accepts any certificate, including self-signed ones. That is convenient against development servers and unsafe against production ones. Pass your own callback to enforce verification:

```dart
final pool = MysqlConnectionPool.fromUri(
  'mysql://app:secret@db.example.com:3306/app?ssl=true',
  onBadCertificate: (certificate) => false, // reject unverifiable certs
);
```

`fromConfig` installs no permissive default: it forwards exactly the callback you give it. See the [security guide](../guides/security.md) for the wider picture.
:::

## Pooling

Both factories wrap the driver's native pool. `fromConfig` additionally participates in the isolate-wide `maxTotalConnections` reservation: pool sizes are clamped to the remaining slots, and `ConfigurationException` (key `maxTotalConnections`) is thrown when none remain. Slots return on `close()`. `fromUri` does not reserve slots.

Both factories set collation `utf8mb4_general_ci`. Live diagnostics: `pool.activeConnections` and `pool.idleConnections`.

## Capability profile

`mysqlAdapterCapabilities` is a package-level const shared with the transaction adapter:

| Flag | Value |
| --- | --- |
| `supportsTransactions` | `true` |
| `supportsSavepoints` | `true` |
| `supportsStreaming` | `true` |
| `supportsRawQuery` | `true` |
| `supportsReturning` | `false` |
| `supportsJoins` | `true` |
| `supportsPreparedStatements` | `true` |
| `supportsPartialIndexes` | `false` |
| `supportsAggregations` | `true` |
| `supportsSchemaIntrospection` | `true` |
| `supportsExplain` | `true` |

MySQL has no partial (filtered) indexes and no `RETURNING` clause.

## Dialect notes

- Identifiers are backtick-quoted (`` `users` ``), with embedded backticks doubled.
- Placeholders are positional `?` markers, bound through server-side prepared statements. Values are never string-interpolated.
- No `RETURNING`: `insert()` echoes the values you supplied, projected to the `returning` columns when set. When you did not supply an `id` and set no `returning` list, the adapter injects `id` from `LAST_INSERT_ID()` if the table generated one. Other database-computed defaults are not read back.
- `ILIKE` is emulated as `LOWER(column) LIKE LOWER(?)`.
- `OFFSET` requires a `LIMIT`; integer primary keys compile to `AUTO_INCREMENT`; tables are created with `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`.
- Value binding: `bool` becomes `0`/`1`, `DateTime` becomes a MySQL-canonical literal (microseconds preserved), `Map`/`List` are JSON-encoded, `Uint8List` passes through.
- `inList`/`notInList` values chunk at `kMysqlInListChunkSize` (1000).
- `SchemaOperation.alter` is not implemented in the V1 compiler and throws `QueryException`.

## Error mapping

`MysqlErrorMapper` classifies server errors by MySQL error number:

| Native code | Meaning | Worm exception |
| --- | --- | --- |
| `1062`, `1169` | duplicate entry | `UniqueConstraintException` |
| `1451`, `1452`, `1216`, `1217` | foreign-key violation | `ForeignKeyException` |
| `1406`, `1264`, `1265`, `1292`, `1366` | data too long, out of range, truncated or incorrect value | `DataException` |
| `1048`, `3819`, `4025` | column cannot be null, check constraint violated | `CheckConstraintException` |
| `1205` | lock wait timeout | `TransactionException` |
| `1213` | deadlock | `TransactionException` |
| `1042`, `1043`, `1045`, `2002`, `2003`, `2006`, `2013` | connection failures | `ConnectionException` |
| any other code | | `QueryException` |

Client-side and protocol exceptions carry no error number and map to `QueryException`. The mapper also extracts the constraint name from duplicate-entry messages (`for key 'tbl.PRIMARY'`). See [exceptions](../reference/exceptions.md).

## Transactions and savepoints

`transaction()` checks out one connection, issues `START TRANSACTION`, and hands your callback a `MysqlTransactionAdapter` pinned to that connection. Success commits; a throw rolls back and rethrows your original exception. Nested `transaction()` calls become savepoints named `worm_sp_1`, `worm_sp_2`, and so on, released on success and rolled back to on failure.

## EXPLAIN

`explain()` runs `EXPLAIN FORMAT=JSON` over the compiled SELECT. `usesIndex` is `true` when any table node reports an index-based `access_type` (`eq_ref`, `ref`, `const`, `range`, `index_merge`, `index`, `fulltext`); `indexName` comes from the plan's `key` entry; `scannedTables` lists tables with `access_type: "ALL"` (full scans).

## Prepared statements

The adapter prepares a server-side statement per execution and deallocates it afterwards: the pool hands out a fresh connection each call, so handles cannot be reused across check-outs. `MysqlPreparedStatementCache` (default `maxSize: 100`) holds no driver handles; it is an observability LRU that records which SQL strings repeat, so `adapter.preparedStatementCache.missRate` tells you how much re-preparing your workload pays for.

## Aggregate typing

MySQL returns `SUM` and `AVG` over integer columns as `DECIMAL`, which the driver surfaces as strings. The adapter's parsers coerce `int`, `num`, and `String` shapes and throw `QueryException` for anything else. Aggregates over zero rows yield `null` for `sum`, `avg`, `min`, and `max`.

## Contract tests

The conformance suite is gated by the `MYSQL_URL` environment variable and skips gracefully without a server:

```dart title="test/mysql_contract_test.dart"
final url = Platform.environment['MYSQL_URL'];
// skip when unset ...
runAdapterContractTests(
  name: 'MysqlAdapter contract',
  capabilities: mysqlAdapterCapabilities,
  adapterFactory: () async =>
      MysqlAdapter(pool: MysqlConnectionPool.fromUri(url)),
);
```

The monorepo's `docker-compose.yml` provides a `mysql` service on host port 3310 (`mysql://worm:worm@127.0.0.1:3310/worm_test`).

## Gotchas

- `fromUri` with TLS accepts bad certificates by default. Always pass `onBadCertificate` for production endpoints.
- `insert()` echoes your values and only enriches `id` from `LAST_INSERT_ID()`. Column defaults computed by the database are not read back.
- The `LAST_INSERT_ID()` enrichment is skipped when you pass a `returning` list or supply your own `id`.
- `ILIKE` emulation wraps both sides in `LOWER()`, which can bypass an index on the raw column.
- `stream()` is buffered: it selects all rows first, then yields them.
- `maxTotalConnections` reservation applies to `fromConfig` only; `fromUri` pools live outside the cap.
- `SchemaOperation.alter` throws `QueryException`; use `rawExecute` for `ALTER TABLE` today.

## Continue reading

- [Security](../guides/security.md): the TLS callout above in context, plus injection and mass-assignment defenses.
- [Choosing a database](./choosing-a-database.mdx): how MySQL's profile compares to Postgres and SQLite.
- [Transactions](../database/transactions.md): the application-level transaction API built on this adapter.
