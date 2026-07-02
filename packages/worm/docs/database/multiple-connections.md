---
title: Multiple connections
description: Register several databases by name, route models between them, and understand how Worm.adapter() resolves a connection.
---

Worm can talk to several databases at once: adapters are registered under connection names, and models, queries, and transactions can each target one. This page builds on [configuration](../start-here/configuration.md) and assumes you know [transactions](./transactions.md).

## Registering connections

`Worm.initialize` takes a map of adapters keyed by connection name. One key must match `WormConfig.defaultConnection` (which defaults to `'default'`), or initialization throws `ConfigurationException` with key `adapter.missing`:

```dart title="bin/server.dart"
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

Future<void> main() async {
  final primary = PostgresAdapter(
    pool: PostgresConnectionPool.fromConfig(
      const ConnectionConfig(
        driver: 'postgres',
        host: 'localhost',
        database: 'app',
        username: 'app',
        password: 'secret',
      ),
    ),
  );
  final analytics = SqliteAdapter.open('analytics.db');

  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{
      'default': primary,
      'analytics': analytics,
    },
  );
}
```

`initialize` connects every adapter. `Worm.registeredConnections` lists the registered names.

## How Worm.adapter() resolves

`Worm.adapter([name])` returns the adapter for a connection name, defaulting to `WormConfig.defaultConnection` when you omit the argument. Resolution order, verified against the source:

1. **Active test transaction.** While `Worm.beginTestTransaction()` is open, requests for the default connection return the test transaction's handle. Other connections are unaffected.
2. **Ambient transaction.** Inside a `Worm.transaction` whose `connectionName` matches the requested name, the transactional adapter is returned, so work enlists automatically.
3. **The registry.** Otherwise the adapter registered under that name is returned. An unknown name throws `ConfigurationException` with key `adapter.unknown`; calling before `initialize` throws with key `initialization`.

This ordering is why saves inside a transaction join it without an explicit `transaction:` parameter, and why test transactions capture all default-connection work.

## Routing models to a connection

The mechanism that routes reads and writes is the model's `connectionName` getter. It defaults to `'default'`; override it to move a model:

```dart
final class AuditLog extends Model {
  @override
  String get connectionName => 'analytics';

  // id, tableName, toRow, ...
}
```

With codegen, annotate instead:

```dart
@Table(name: 'audit_logs', connection: 'analytics')
final class AuditLog extends Model with _$AuditLogAnnotations {
  // ...
}
```

A non-default `@Table(connection:)` makes the generator emit a `_$AuditLogAnnotations` mixin containing exactly that `connectionName` override. The mixin is opt-in: you must add `with _$AuditLogAnnotations` yourself, or the annotation has no runtime effect. See [code generation](../models/code-generation.md).

`ModelRegistration(connection: 'analytics')` records the same fact in the runtime registry. Keep it consistent with the model's `connectionName`; the persistence path reads the getter, not the registration.

Everything downstream follows the getter: `save`, `delete`, and `refresh` resolve `Worm.adapter(model.connectionName)`, and generated relation accessors resolve the parent's connection the same way.

## Queries and the default connection

One asymmetry to know about: the generated static `query()` starter calls `Worm.adapter()` with no argument, so it always targets the default connection, even for a model annotated with another connection. To query a model on a non-default connection, build the builder yourself with an explicit `QueryContext`:

```dart
final logs = await QueryBuilder<AuditLog>.from(
  QueryContext<AuditLog>(
    adapter: Worm.adapter('analytics'),
    table: 'audit_logs',
    hydrate: AuditLogHydration.fromRow,
  ),
).get();
```

`AuditLogHydration.fromRow` is the generated hydrator; hand-written models supply their own `Hydrator<T>` function.

## Transactions across connections

Transactions are per connection. Target one by name:

```dart
await Worm.transaction(
  (txn) async {
    await auditLog.save(); // enlists: connection names match
  },
  connection: 'analytics',
);
```

Two rules follow from the resolution order above:

- A nested `Worm.transaction` on a **different** connection opens its own independent transaction. There is no two-phase commit: one can commit while the other rolls back.
- A model whose `connectionName` differs from the ambient transaction's connection does not enlist. Its save commits on its own connection immediately.

Test transactions (`beginTestTransaction`) cover only the default connection. Writes to other connections during a test persist unless you clean them up yourself.

## Pooling and connection caps

`ConnectionConfig` carries the pool parameters adapter packages consume: `poolSize` (default 10) is the number of connections held per isolate, `connectionTimeout` (default 5 seconds) bounds acquisition, and `idleTimeout` (default 300 seconds) retires idle connections. A `port` of `0` means "unset"; adapters substitute their protocol default (5432 for Postgres).

`maxTotalConnections` (default `null`, meaning no cap) limits the combined pool size across every connection built in the current isolate. The Postgres pool enforces it with an isolate-wide reservation counter: later pools get their `poolSize` clamped to whatever headroom remains, and when nothing remains, `PostgresConnectionPool.fromConfig` throws `ConfigurationException` with key `maxTotalConnections`. With several named Postgres connections in one process, set the cap once and size each `poolSize` deliberately.

## Gotchas

- The adapters map must contain the default connection name, or `initialize` throws (`adapter.missing`).
- Generated `query()` starters always use the default connection. Use an explicit `QueryContext` for models on other connections.
- `@Table(connection:)` only takes effect if you mix in the generated `_$<Model>Annotations` mixin.
- `ModelRegistration(connection:)` is registry metadata; the write path reads `Model.connectionName`. Keep them in sync.
- Cross-connection transactions are independent. A rollback on one connection never undoes commits on another.
- Test transactions isolate the default connection only.
- `maxTotalConnections` is enforced per isolate, by reservation at pool construction time; it clamps later pools rather than resizing earlier ones.

## Continue reading

- [Configuration](../start-here/configuration.md): `Worm.initialize`, `WormConfig`, and `ConnectionConfig` from the top.
- [Transactions](./transactions.md): joining, savepoints, and `afterCommit` on a single connection.
- [Choosing a database](../drivers/choosing-a-database.mdx): pick the right adapter for each connection.
- [Configuration options reference](../reference/configuration-options.md): every `WormConfig` and `ConnectionConfig` field.
