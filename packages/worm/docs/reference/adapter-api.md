---
title: Adapter API
description: The complete DatabaseAdapter contract, every AdapterCapabilities flag, and every descriptor type that crosses the adapter boundary.
---

This page is the full reference for the adapter boundary: the `DatabaseAdapter` contract, the `AdapterCapabilities` matrix, and every descriptor and support type an adapter consumes or produces. For the concept walkthrough, read [how drivers work](../drivers/how-drivers-work.md) first; to build your own adapter, follow [writing a database driver](../contributing/writing-a-database-driver.md).

## Mini-index

| Symbol | One-liner |
| --- | --- |
| [`DatabaseAdapter`](#databaseadapter) | The abstract contract every driver implements |
| [`AdapterCapabilities`](#adaptercapabilities) | Const feature matrix, all 11 flags default `false` |
| [`AdapterType`](#adaptertype) | Adapter family enum gating `.sql()` / `.mongo()` contexts |
| [`QueryDescriptor`](#querydescriptor) | Immutable SELECT description |
| [`InsertDescriptor` / `InsertManyDescriptor`](#insertdescriptor-and-insertmanydescriptor) | Single-row and multi-row INSERT descriptions |
| [`UpdateDescriptor` / `DeleteDescriptor`](#updatedescriptor-and-deletedescriptor) | UPDATE and DELETE descriptions |
| [`AggregateDescriptor` / `AggregateFunction`](#aggregatedescriptor-and-aggregatefunction) | Aggregate query description and its function enum |
| [`SchemaDescriptor` family](#schemadescriptor-family) | DDL descriptions: operations, columns, indexes |
| [Clause types](#clause-types) | `SortClause`, `SortDirection`, `JoinClause`, `JoinKind`, `HavingClause` |
| [`EagerLoad` / `AggregateInjection`](#eagerload-and-aggregateinjection) | Builder-side relation specs (resolved before the adapter) |
| [`QueryContext` / `Hydrator`](#querycontext-and-hydrator) | Per-model context the query builder runs against |
| [`TransactionContext`](#transactioncontext) | Live transaction handle with public `savepoint` |
| [`PredicateEvaluator`](#predicateevaluator) | Shared in-memory predicate semantics for adapters |
| [`ExplainCapable` / `ExplainResult`](#explaincapable-and-explainresult) | Opt-in EXPLAIN mixin and its result type |

Rows cross the adapter boundary in both directions as `Map<String, Object?>`. Descriptors go in; maps come out. All types below are exported from `package:worm/worm.dart`.

## DatabaseAdapter

```dart
abstract class DatabaseAdapter {
  const DatabaseAdapter({
    AdapterCapabilities capabilities = const AdapterCapabilities(),
  });
}
```

`DatabaseAdapter` is `abstract` (not `sealed`), so third-party packages can implement it. The base constructor stores the declared capability matrix; `capabilities` is a getter so adapters whose capabilities depend on runtime state (for example replica-set detection after a MongoDB connection opens) can override and compute it at access time.

### Getters

| Member | Signature | Notes |
| --- | --- | --- |
| `capabilities` | `AdapterCapabilities get capabilities` | Declared matrix; overridable for runtime-detected capabilities. |
| `adapterType` | `AdapterType get adapterType` | Defaults to `AdapterType.custom`. SQL and Mongo adapters override it to enable the `.sql()` / `.mongo()` query contexts. |

### Lifecycle

| Method | Signature | Notes |
| --- | --- | --- |
| `connect` | `Future<void> connect()` | Establish the connection or initialize the backing store. Safe to call multiple times. |
| `disconnect` | `Future<void> disconnect()` | Close connections and release all resources. |

### Reads

| Method | Signature | Notes |
| --- | --- | --- |
| `select` | `Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor)` | All matching rows. |
| `selectOne` | `Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor)` | First matching row, or `null` when nothing matches. |
| `stream` | `Stream<Map<String, Object?>> stream(QueryDescriptor descriptor)` | Cursor-based iteration with bounded memory. |

### Writes

| Method | Signature | Notes |
| --- | --- | --- |
| `insert` | `Future<Map<String, Object?>> insert(InsertDescriptor descriptor)` | Inserts one row and returns it. |
| `insertMany` | `Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor descriptor)` | Inserts multiple rows and returns them. |
| `update` | `Future<int> update(UpdateDescriptor descriptor)` | Returns the affected row count. |
| `delete` | `Future<int> delete(DeleteDescriptor descriptor)` | Returns the affected row count. |

### Aggregates

| Method | Signature | Notes |
| --- | --- | --- |
| `count` | `Future<int> count(AggregateDescriptor descriptor)` | Row count over the match. |
| `sum` | `Future<num?> sum(AggregateDescriptor descriptor)` | `null` when no rows match. |
| `avg` | `Future<double?> avg(AggregateDescriptor descriptor)` | `null` when no rows match. |
| `min` | `Future<Object?> min(AggregateDescriptor descriptor)` | Minimum value of the column. |
| `max` | `Future<Object?> max(AggregateDescriptor descriptor)` | Maximum value of the column. |
| `aggregateGrouped` | `Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor descriptor)` | One entry per distinct `groupBy` value. Has a concrete default (fetch and roll up in memory), so existing adapters need not implement it. Returns an empty map when `descriptor.groupBy` is `null`. SQL and document adapters override it to push the `GROUP BY` into the database. |

### Raw access

| Method | Signature | Notes |
| --- | --- | --- |
| `rawQuery` | `Future<List<Map<String, Object?>>> rawQuery(String query, List<Object?> parameters)` | Raw parameterized read. |
| `rawExecute` | `Future<int> rawExecute(String statement, List<Object?> parameters)` | Raw parameterized write; returns the affected count. |

### Transactions

| Method | Signature | Notes |
| --- | --- | --- |
| `transaction` | `Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action)` | Runs `action` inside a transaction. The nested adapter passed to `action` represents the transactional context. Throwing inside `action` rolls the transaction back. |

### Schema

| Method | Signature | Notes |
| --- | --- | --- |
| `executeSchema` | `Future<void> executeSchema(SchemaDescriptor descriptor)` | Applies a DDL operation. |
| `introspectSchema` | `Future<Map<String, List<String>>> introspectSchema()` | Live schema as table name to declared columns. Adapters that do not persist column lists return an empty list per known table. |

### Debugging

| Method | Signature | Notes |
| --- | --- | --- |
| `compileToString` | `String compileToString(Object descriptor)` | Compiles a descriptor to its native string form for logging or debugging. Synchronous. Never executes anything. |

:::note[explain is not on the contract]
`explain` lives on the [`ExplainCapable`](#explaincapable-and-explainresult) mixin, not on `DatabaseAdapter`. Consumers gate access via `capabilities.supportsExplain` plus an `is ExplainCapable` check.
:::

## AdapterCapabilities

```dart
const AdapterCapabilities({
  bool supportsTransactions = false,
  bool supportsSavepoints = false,
  bool supportsStreaming = false,
  bool supportsRawQuery = false,
  bool supportsReturning = false,
  bool supportsJoins = false,
  bool supportsPreparedStatements = false,
  bool supportsPartialIndexes = false,
  bool supportsAggregations = false,
  bool supportsSchemaIntrospection = false,
  bool supportsExplain = false,
})
```

All 11 flags default to `false`: adapters opt in explicitly. The type only describes capability. Enforcement (throwing `UnsupportedOperationException` when an unsupported method is invoked) is each adapter's responsibility.

| Flag | `supports()` key | Meaning |
| --- | --- | --- |
| `supportsTransactions` | `'transactions'` | Transactions work; checked by `Worm.transaction` before opening one. |
| `supportsSavepoints` | `'savepoints'` | Nested savepoints inside a transaction; checked by `TransactionContext.savepoint`. |
| `supportsStreaming` | `'streaming'` | Cursor-based streaming reads. |
| `supportsRawQuery` | `'rawQuery'` | Raw native query pass-through. |
| `supportsReturning` | `'returning'` | `RETURNING`-style clauses on writes. |
| `supportsJoins` | `'joins'` | SQL joins. |
| `supportsPreparedStatements` | `'preparedStatements'` | Prepared statement caching. |
| `supportsPartialIndexes` | `'partialIndexes'` | Partial (filtered) indexes. |
| `supportsAggregations` | `'aggregations'` | Aggregate functions. |
| `supportsSchemaIntrospection` | `'schemaIntrospection'` | Live schema introspection. |
| `supportsExplain` | `'explain'` | Can render an EXPLAIN plan; gates the `MissingIndexWarner`. |

Other members:

| Member | Signature | Notes |
| --- | --- | --- |
| `supports` | `bool supports(String capability)` | Safe string lookup using the keys above. Returns `false` for unknown keys. Never throws. |
| `copyWith` | `AdapterCapabilities copyWith({...})` | Copy with any subset of flags overridden. |

## AdapterType

```dart
enum AdapterType { sql, mongodb, inMemory, custom }
```

| Value | Meaning |
| --- | --- |
| `sql` | Relational backends with a SQL surface (`worm_postgres`, `worm_sqlite`, `worm_mysql`). |
| `mongodb` | Document backends (`worm_mongodb`). |
| `inMemory` | The bundled `InMemoryAdapter`; supports neither raw SQL nor Mongo pipelines. |
| `custom` | Default for third-party adapters that do not opt into a bundled family. |

The `.sql()` and `.mongo()` gates on `QueryBuilder` consult `DatabaseAdapter.adapterType` to decide whether the caller targets the right backend. A related helper, `String adapterName(DatabaseAdapter adapter)`, returns the adapter's runtime type name for error messages.

## Descriptors

Descriptors are the immutable, database-agnostic language between the query builder and adapters. Every one is `const`-constructible and exposes `toMap()` for golden-snapshot testing without a database.

### QueryDescriptor

```dart
const QueryDescriptor({
  required String table,
  List<String> columns = const [],
  PredicateTree? where,
  List<SortClause> orderBy = const [],
  int? limit,
  int? offset,
  bool distinct = false,
  List<JoinClause> joins = const [],
  List<String> groupBy = const [],
  List<HavingClause> having = const [],
})
```

| Field | Type | Notes |
| --- | --- | --- |
| `table` | `String` | Target table. |
| `columns` | `List<String>` | Projection; empty means all columns. |
| `where` | `PredicateTree?` | Optional predicate tree (see [operators and fields](./operators-and-fields.md)). |
| `orderBy` | `List<SortClause>` | ORDER BY clauses in order. |
| `limit` / `offset` | `int?` | Pagination window. |
| `distinct` | `bool` | Return only distinct rows. |
| `joins` | `List<JoinClause>` | SQL adapters only; non-SQL adapters reject join-bearing descriptors. |
| `groupBy` | `List<String>` | SQL adapters only. |
| `having` | `List<HavingClause>` | SQL adapters only; applied after grouping. |

`copyWith(...)` overrides selected fields; pass `clearWhere: true` to reset `where` back to `null` (a plain `copyWith(where: null)` keeps the existing tree).

### InsertDescriptor and InsertManyDescriptor

```dart
const InsertDescriptor({
  required String table,
  required Map<String, Object?> values,
  List<String>? returning,
})

const InsertManyDescriptor({
  required String table,
  required List<Map<String, Object?>> rows,
  List<String>? returning,
})
```

`returning` lists the columns to return; `null` means all columns.

### UpdateDescriptor and DeleteDescriptor

```dart
const UpdateDescriptor({
  required String table,
  required Map<String, Object?> values,
  PredicateTree? where,
})

const DeleteDescriptor({required String table, PredicateTree? where})
```

A `null` `where` matches every row. The strictness flag `preventDestructiveWithoutWhere` blocks such descriptors at the query-builder level before they reach the adapter (see [strict mode](../guides/strict-mode.md)).

### AggregateDescriptor and AggregateFunction

```dart
enum AggregateFunction { count, sum, avg, min, max }

const AggregateDescriptor({
  required String table,
  required AggregateFunction function,
  String? column,
  PredicateTree? where,
  String? groupBy,
})
```

| Field | Notes |
| --- | --- |
| `column` | Column to aggregate over; `null` for `COUNT(*)`-style aggregations. |
| `groupBy` | When set, the aggregate is computed per distinct value of this column and the adapter returns one value per group via `aggregateGrouped`. Used by the eager loader for `withCount` / `withSum` rollups. |

A convenience constructor exists for counting: `AggregateDescriptor.count({required String table, String? column, PredicateTree? where, String? groupBy})`.

### SchemaDescriptor family

```dart
enum SchemaOperation { create, drop, alter, truncate, createIndex }

const SchemaDescriptor({
  required String table,
  required SchemaOperation operation,
  List<SchemaColumn> columns = const [],
  List<SchemaIndex> indexes = const [],
  bool ifNotExists = false,
  bool ifExists = false,
})
```

`SchemaDescriptor` is a `base class` so adapter-facing subtypes can extend it. Named constructors: `SchemaDescriptor.createTable({table, columns, indexes, ifNotExists})`, `SchemaDescriptor.dropTable({table, ifExists})`, `SchemaDescriptor.truncateTable({table})`.

| Type | Fields | Notes |
| --- | --- | --- |
| `SchemaColumn` | `name`, `type` (`ColumnType`), `nullable = false`, `defaultValue`, `isPrimaryKey = false` | One abstract column definition. `ColumnType` covers string, integer sizes, decimal, boolean, date/time, uuid, json/jsonb, text, binary, and more. |
| `SchemaIndex` | `name`, `columns`, `unique = false` | One abstract index definition carried on create/alter. |
| `SchemaIndexDescriptor` | `collection`, `field`, `unique = false` | Extends `SchemaDescriptor` with `operation: SchemaOperation.createIndex`. SQL adapters compile it to `CREATE [UNIQUE] INDEX`; Mongo-style adapters translate it to `createIndex`. |

### Clause types

| Type | Shape | Notes |
| --- | --- | --- |
| `SortClause` | `const SortClause(String fieldName, {String? tableName, SortDirection direction = SortDirection.asc})` | One ORDER BY entry; `tableName` is an optional qualifier. Implements `==` and `hashCode`. |
| `SortDirection` | `enum SortDirection { asc, desc }` | Sort direction. |
| `JoinClause` | `const JoinClause({required JoinKind kind, required String table, required String leftColumn, required String rightColumn})` | `<kind> <table> ON <left> = <right>`. SQL-only; columns are qualified (`posts.user_id`). |
| `JoinKind` | `enum JoinKind { inner, left }` with `String get sql` | Renders `INNER JOIN` or `LEFT JOIN`. |
| `HavingClause` | `const HavingClause({required String expression, required Operator operator, required Object? value})` | `expression` is a raw aggregate expression such as `'COUNT(*)'`, emitted verbatim. `value` is parameterized. |

:::caution
`HavingClause.expression` is a developer-authored escape hatch, like `whereRaw`. It is not parameterized. Never build it from untrusted input.
:::

### EagerLoad and AggregateInjection

These two types ride on the `QueryBuilder`, not on descriptors. The eager loader resolves them into ordinary `QueryDescriptor` / `AggregateDescriptor` batches before anything reaches your adapter, so adapter authors never handle them directly.

| Type | Shape | Notes |
| --- | --- | --- |
| `EagerLoad` | `const EagerLoad(String path, {PredicateTree? constrain})` | One eager-load entry. `path` is a dot-separated relation path (`'posts'` or `'posts.comments'`); `head` / `tail` getters split it. `constrain` is AND-merged into the child SELECT for the head segment only. |
| `AggregateInjection` | `const AggregateInjection({required String relationName, required AggregateKind kind, required String injectionKey, String? column, PredicateTree? filter})` | Drives `withCount`, `withSum`, and `withExists`. The result lands under `injectionKey` in `Model.injectedFields`. |
| `AggregateKind` | `enum AggregateKind { count, sum, exists }` | Kind of injected aggregate. `column` is used only for `sum`. |

## QueryContext and Hydrator

```dart
typedef Hydrator<T> = T Function(Map<String, Object?> row);

const QueryContext({
  required DatabaseAdapter adapter,
  required String table,
  required Hydrator<T> hydrate,
  String primaryKey = 'id',
  List<GlobalScope<Model>> globalScopes = const [],
  Map<String, Relation<Model, Model>> relations = const {},
})
```

`QueryContext<T extends Model>` is the immutable per-model context that `QueryBuilder<T>` needs to produce, execute, and hydrate queries: the adapter to run against, the table, the primary key column, the hydrator that turns a raw row into a typed model, the global scopes auto-applied to every query, and the declared relations keyed by name. Generated code builds it for you; you construct one by hand only when driving the core without codegen.

## TransactionContext

The live transaction handle passed to `Worm.transaction` callbacks and accepted by `Model.save(transaction:)` / `Model.delete(transaction:)`. User code receives one; it never constructs one (the constructor is `@internal`).

| Member | Signature | Notes |
| --- | --- | --- |
| `adapter` | `final DatabaseAdapter adapter` | The transactional adapter handle. Writes routed through it participate in the transaction. |
| `connectionName` | `final String connectionName` | The connection this transaction was opened on. |
| `savepoint` | `Future<T> savepoint<T>(Future<T> Function() body)` | Nested rollback boundary. On success the savepoint is released; when `body` throws, only the savepoint's own work rolls back, the exception propagates, and the outer transaction survives. Throws `UnsupportedOperationException` when `capabilities.supportsSavepoints` is `false`. |

`enqueueAfterCommit`, `drainAfterCommit`, and `discardAfterCommit` are marked `@internal`: the model layer uses them to defer `afterCommit` callbacks until the outermost commit. Callbacks registered inside a rolled-back savepoint are discarded. See [transactions](../database/transactions.md) for usage.

## PredicateEvaluator

```dart
const PredicateEvaluator();

bool matches(
  Map<String, Object?> row,
  PredicateTree? tree, {
  bool Function(ExistsNode node)? existsResolver,
})
```

A stateless, `const`-constructible evaluator of `PredicateTree` instances against raw rows. A `null` tree matches every row. Adapters backed by an in-memory store (including the bundled `InMemoryAdapter`) delegate filtering here so predicate semantics stay consistent: LIKE patterns, inclusive BETWEEN, and NULLS-FIRST comparisons via the public `compareValues(Object? a, Object? b)`.

Limits: `RawNode` (from `whereRaw`) throws `UnsupportedOperationException`, as do column-to-column LIKE/IN/BETWEEN/NULL comparisons; `ExistsNode` requires an `existsResolver` or throws. Comparing non-`Comparable` values throws `StateError`.

## ExplainCapable and ExplainResult

```dart
abstract mixin class ExplainCapable {
  Future<ExplainResult> explain(QueryDescriptor descriptor);
}

const ExplainResult({
  required bool usesIndex,
  String raw = '',
  String? indexName,
  double estimatedCost = 0,
  int estimatedRows = 0,
  List<String> scannedTables = const [],
})
```

Mix `ExplainCapable` into an adapter to expose query plans without executing queries. The strictness layer probes adapters via `is ExplainCapable`; `MissingIndexWarner.checkAfterQuery` is a hard no-op unless the adapter both declares `supportsExplain` and mixes this in, so it can be wired unconditionally. `ExplainResult.usesIndex` reports whether at least one predicate is satisfied by an index; `estimatedCost` and `estimatedRows` of `0` mean unknown.

## Capability profiles of the shipped drivers

Each shipped driver declares its own honest profile: for example `InMemoryAdapter` defaults to transactions, savepoints, streaming, returning, aggregations, schema introspection, and explain enabled, with joins and rawQuery disabled. The full per-driver comparison lives on [choosing a database](../drivers/choosing-a-database.mdx).

## Gotchas

- Capabilities describe; adapters enforce. Declaring `supportsTransactions: false` makes `Worm.transaction` throw `UnsupportedOperationException` before your adapter is even called, but your adapter must still throw its own `UnsupportedOperationException` from `transaction()` for direct callers.
- `selectOne` returns `null` on no match; it never throws. `firstOrFail` semantics live in the query builder, not the adapter.
- `sum` and `avg` return `null` when no rows match; `count` returns `0`.
- `aggregateGrouped` returns an empty map when `descriptor.groupBy` is `null`.
- `compileToString` is synchronous and must never execute the descriptor.
- `explain` is not a `DatabaseAdapter` method; it comes from the `ExplainCapable` mixin.
- `EagerLoad` and `AggregateInjection` never reach adapters; the eager loader lowers them to plain descriptors first.

## Continue reading

- [How drivers work](../drivers/how-drivers-work.md): the concept-level tour of descriptors in, maps out.
- [Writing a database driver](../contributing/writing-a-database-driver.md): implement this contract and validate it with the shared conformance suite.
- [Exceptions](./exceptions.md): the typed exceptions adapters are expected to map native errors into.
- [Choosing a database](../drivers/choosing-a-database.mdx): the capability matrix across all shipped drivers.
