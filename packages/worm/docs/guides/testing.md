---
title: Testing
description: A copy-paste playbook for fast, isolated worm tests with in-memory databases, test transactions, factories, and query assertions.
---

This page gives you a complete test harness for a worm app: a fresh database per test, clean teardown, reproducible fake data, and assertions on the queries your code actually runs. It builds on [the in-memory driver](../drivers/in-memory.md) and [factories](../models/factories.md).

## The playbook

The default recipe: one fresh `InMemoryAdapter` per test, schema created up front, `Worm.reset` in `tearDown`. Every test starts from an empty database and leaves nothing behind.

```dart title="test/support/test_database.dart"
import 'package:worm/worm.dart';

/// Connects a fresh in-memory database, creates the schema, and
/// initializes the Worm runtime against it.
Future<InMemoryAdapter> createTestDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'users',
      columns: <SchemaColumn>[
        SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
        SchemaColumn(name: 'name', type: ColumnType.text),
        SchemaColumn(name: 'email', type: ColumnType.text),
      ],
    ),
  );
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
    models: const <ModelRegistration>[
      ModelRegistration(type: User, tableName: 'users'),
    ],
  );
  return adapter;
}
```

```dart title="test/user_test.dart"
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import 'support/test_database.dart';
import 'support/user_factory.dart';

void main() {
  setUp(() async {
    Worm.seedRandom(42);
    await createTestDatabase();
  });

  tearDown(Worm.reset);

  test('finds a user by name', () async {
    await UserFactory().create(overrides: {'name': 'Alice'});

    final found = await User.query().where(User$.name.eq('Alice')).first();

    expect(found, isNotNull);
  });
}
```

`Worm.reset()` rolls back any active test transaction, disconnects every registered adapter, and clears the model, observer, and morph registries. After it runs, `Worm` is uninitialized again, so the next `setUp` can call `Worm.initialize` without hitting the double-init guard (`ConfigurationException` with key `initialization.duplicate`).

:::tip[Prefer executeSchema over migrations in tests]
`executeSchema` with a `SchemaDescriptor.createTable` is the fastest way to a schema in tests. If you want your tests to exercise the real migration path instead, build a `MigrationRunner` with your migration list and call `migrate()` against the test adapter. See [migrations](../database/migrations.md).
:::

Every test gets a whole database to itself. Birds don't share worms either.

## Which adapter to test against

`InMemoryAdapter` is the default choice: no I/O, no files, and a capability profile that covers transactions, savepoints, streaming, aggregations, and explain. When you want real SQL semantics (SQL types, constraint errors, raw queries), `SqliteAdapter.memory()` from `worm_sqlite` gives you an actual SQLite database that still lives entirely in RAM. The harness above is identical; only the adapter construction changes.

Two `InMemoryAdapter` behaviors worth knowing in tests:

- `rawQuery` and `rawExecute` throw `UnsupportedOperationException` (its capabilities declare `supportsRawQuery: false`). Use `SqliteAdapter.memory()` when your code under test issues raw SQL.
- `disconnect()` keeps the stored data; `close()` wipes it. `Worm.reset()` calls `disconnect()`, which is fine because the playbook discards the adapter instance anyway.

## Test transactions for shared databases

A fresh in-memory adapter per test makes isolation trivial. When your suite runs against a shared database instead (a SQLite file, or Postgres in CI), wrap each test in a test transaction: every write during the test happens inside a transaction that is rolled back afterwards.

```dart
setUp(Worm.beginTestTransaction);
tearDown(Worm.rollbackTestTransaction);
```

Semantics, verified against the runtime:

- `beginTestTransaction()` opens a transaction on the **default connection only**. While it's active, `Worm.adapter()` returns the transactional handle, so all default-connection reads and writes go through it. Writes on other connections are not isolated.
- Calling `beginTestTransaction()` while one is already active throws `ConfigurationException` with key `test_transaction.duplicate`.
- `rollbackTestTransaction()` unwinds the transaction and completes only once the adapter has fully rolled back, so the very next line can observe the pre-test state. It's a no-op when no test transaction is active.
- Any `afterCommit` callbacks queued during the test are discarded on rollback; they never fire.
- `Worm.reset()` calls `rollbackTestTransaction()` first, so `tearDown(Worm.reset)` alone is enough if you're doing both.

Test transactions mutate global static state on `Worm`. They're built for tests and are not safe for concurrent production use.

## Seeding test data with factories

Factories build models in memory (`make`, `makeMany`) or persist them (`create`). Combine them with `Worm.seedRandom` so faker output is identical on every run.

```dart title="test/support/user_factory.dart"
import 'package:worm/worm.dart';

int _nextId = 0;

final class UserFactory extends Factory<User> {
  @override
  User definition() => User()
    ..setAttribute('id', ++_nextId)
    ..setAttribute('name', faker.name())
    ..setAttribute('email', faker.email());
}
```

```dart
Worm.seedRandom(42);                      // reproducible faker stream
final users = await UserFactory().count(5).create();   // five persisted rows
final draft = UserFactory().make();                    // built, not saved
```

`create(overrides: {...})` applies overrides through `fill()`, so guarded fields on the model are subject to the usual [mass assignment](../models/mass-assignment.md) rules. See [factories](../models/factories.md) for states, sequences, and `has()`/`for_()` relation graphs.

## Asserting on the queries your code runs

Wrap the test adapter in a `LoggingAdapter` with an `InMemoryQueryLogger` and you can assert on every statement, its parameters, and which table it hit. This is how you write a regression test for an N+1 fix.

```dart
final logger = InMemoryQueryLogger();
final adapter = LoggingAdapter(
  inner: InMemoryAdapter(),
  logger: logger,
  strictness: const StrictnessConfig(),
  adapterName: 'InMemory',
);
// connect, executeSchema, and Worm.initialize with `adapter` as usual
logger.clear(); // setup queries (like executeSchema) are logged too

await User.query().where(User$.name.eq('Alice')).get();

expect(logger.entries, hasLength(1));
final entry = logger.entries.single;
expect(entry.table, 'users');
expect(entry.parameters, ['Alice']);
```

`InMemoryQueryLogger` also exposes `slowQueries` (entries at or over `StrictnessConfig.slowQueryThreshold`), `lines` (the formatted log output), and `clear()`. To assert "this endpoint runs at most N queries", check `logger.entries.length`. The full logging surface is on [logging and debugging](./logging-and-debugging.md).

## Golden testing queries and descriptors

You don't need a database to test that a query is built correctly. `toSql()` compiles the builder to a deterministic string with literals inlined, and every descriptor has a `toMap()` for structured snapshots.

```dart
test('adult users query compiles as expected', () {
  final sql = User.query()
      .where(User$.age, Operator.gte, 18)
      .orderBy(User$.age, descending: true)
      .limit(10)
      .toSql();

  expect(sql, 'SELECT * FROM users WHERE age >= 18 ORDER BY age DESC LIMIT 10');
});
```

`toSql()` output is for inspection and goldens only. It is not executable SQL; adapters parameterize their real statements separately.

## Testing a custom driver

If you're implementing your own `DatabaseAdapter`, worm ships a conformance suite that exercises CRUD, all operators, sorting, pagination, aggregations, streaming, schema operations, and capability gating against your adapter. It's deliberately not exported from `package:worm/worm.dart`; import it directly in test files:

```dart
import 'package:worm/testing/adapter_contract.dart';

runAdapterContractTests(
  name: 'MyAdapter contract',
  capabilities: const AdapterCapabilities(supportsTransactions: true),
  adapterFactory: () async => MyAdapter(),
);
```

The full walkthrough lives in [writing a database driver](../contributing/writing-a-database-driver.md).

## Gotchas

- `tearDown(Worm.reset)` is not optional. A second `Worm.initialize` without a reset throws `ConfigurationException` (key `initialization.duplicate`).
- `beginTestTransaction()` isolates the default connection only. Multi-connection suites need per-connection strategies.
- A duplicate `beginTestTransaction()` throws; always pair it with `rollbackTestTransaction()` or rely on `Worm.reset()`.
- `afterCommit` callbacks never fire inside a test transaction that gets rolled back. Don't assert on their side effects there.
- `InMemoryAdapter` throws `UnsupportedOperationException` for `rawQuery`/`rawExecute`; use `SqliteAdapter.memory()` for raw SQL paths.
- `InMemoryQueryLogger` grows without bound. That's fine in tests; don't ship it to production.
- `Worm.seedRandom` seeds the shared `FakerService` singleton. Call it in `setUp`, not once per suite, if tests must be order-independent.
- Bulk `update()`/`delete()`/`insertMany()` on the query builder skip lifecycle hooks and validation, so observer-based test doubles won't see them.

## API summary

| Symbol | Signature sketch | What it does |
| --- | --- | --- |
| `InMemoryAdapter` | `InMemoryAdapter({AdapterCapabilities? capabilities})` | Full database in RAM; the default test adapter. `close()` wipes data, `disconnect()` keeps it. |
| `Worm.reset` | `static Future<void> reset()` | Rolls back any test transaction, disconnects all adapters, clears the registry. |
| `Worm.beginTestTransaction` | `static Future<void> beginTestTransaction()` | Opens a rollback-only transaction on the default connection; duplicate call throws `ConfigurationException`. |
| `Worm.rollbackTestTransaction` | `static Future<void> rollbackTestTransaction()` | Rolls the test transaction back; no-op when none is active. |
| `Worm.seedRandom` | `static void seedRandom(int seed)` | Seeds the shared `FakerService` for reproducible factory data. |
| `Factory<T>.make` / `makeMany` | `T make()` / `List<T> makeMany(int count)` | Builds model instances without persisting. |
| `Factory<T>.create` | `Future<T> create({Map<String, Object?> overrides})` | Builds one instance, applies overrides via `fill()`, saves it. |
| `Factory<T>.count(n).create()` | `Future<List<T>> create({...})` | Persists `n` instances in one call. |
| `LoggingAdapter` | `LoggingAdapter({required inner, required logger, required strictness, adapterName})` | Decorator that records every query for assertions. |
| `InMemoryQueryLogger` | `entries`, `slowQueries`, `warnings`, `lines`, `clear()` | Captures queries, slow entries, warnings, and formatted lines in memory. |
| `QueryBuilder<T>.toSql` | `String toSql()` | Deterministic SQL snapshot with inlined literals; inspection only. |
| `QueryDescriptor.toMap` | `Map<String, Object?> toMap()` | Structured descriptor snapshot for golden tests (also on the other descriptors). |
| `runAdapterContractTests` | `void runAdapterContractTests({required adapterFactory, required capabilities, String name})` | Shared conformance suite for driver authors; import `package:worm/testing/adapter_contract.dart`. |

## Continue reading

- [Factories](../models/factories.md): states, sequences, and relation graphs for richer test data.
- [The in-memory driver](../drivers/in-memory.md): capability profile and internals of the default test adapter.
- [Logging and debugging](./logging-and-debugging.md): everything `InMemoryQueryLogger` and `LoggingAdapter` can capture.
- [Writing a database driver](../contributing/writing-a-database-driver.md): the adapter contract kit in depth.
