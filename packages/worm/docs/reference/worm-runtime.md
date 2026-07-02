---
title: Worm runtime
description: Complete reference for every public static member on the Worm runtime class.
---

This page lists every public static member on `Worm`, the central runtime registry exported from `package:worm/worm.dart`. For the narrative version of bootstrapping, read [configuration](../start-here/configuration.md).

`Worm` is a `final` class with a private constructor: you can't instantiate or subclass it. All access goes through the statics below. An older `Worm` implementation exists in the source tree under `worm_registry.dart`; it is not exported and is not documented here.

## Mini-index

| Symbol | One-liner |
| --- | --- |
| [initialize](#initialize) | Boot the runtime: adapters, models, observers |
| [reset](#reset) | Tear everything down (tests) |
| [isInitialized](#isinitialized) | Whether `initialize` has run |
| [config](#config) | The active `WormConfig` |
| [adapter](#adapter) | Resolve a `DatabaseAdapter` by connection name |
| [registrationOf](#registrationof) | Registration metadata for a model type parameter |
| [registrationForType](#registrationfortype) | Registration metadata for a runtime `Type` |
| [models](#models) | All registered models |
| [registeredConnections](#registeredconnections) | Names of all registered connections |
| [observers](#observers) | All registered observers, in registration order |
| [observersFor](#observersfor) | Observers registered for one model type |
| [morphRegistry](#morphregistry) | Shared polymorphic type registry |
| [strictness](#strictness) | Active strictness flags |
| [isUnsafe](#isunsafe) | Whether the current async region is inside `unsafe` |
| [unsafe](#unsafe) | Run a body with strictness gates disabled |
| [transaction](#transaction) | Run a body inside a database transaction |
| [currentTransaction](#currenttransaction) | The ambient `TransactionContext`, or `null` |
| [beginTestTransaction](#begintesttransaction) | Open a test-scoped transaction on the default connection |
| [rollbackTestTransaction](#rollbacktesttransaction) | Roll back the active test transaction |
| [withoutEvents](#withoutevents) | Run a body with lifecycle events muted |
| [mutedEvents](#mutedevents) | The specifically muted events, or `null` |
| [isMutingAll](#ismutingall) | Whether every lifecycle event is muted |
| [isEventMuted](#iseventmuted) | Whether one specific event is muted |
| [seedRandom](#seedrandom) | Seed the shared faker for reproducible factories |
| [environment](#environment) | Current runtime `Environment` (`WORM_ENV` aware) |

## Pre-initialization safety

Most registry members throw `ConfigurationException` with key `'initialization'` when called before `initialize`. A deliberate subset is safe at any time.

| Behavior before `initialize` | Members |
| --- | --- |
| Throws `ConfigurationException('initialization')` | `config`, `models`, `observers`, `morphRegistry`, `adapter`, `registrationOf`, `registrationForType`, `transaction`, `beginTestTransaction` |
| Safe, returns a neutral value | `isInitialized` (`false`), `strictness` (all-off defaults), `environment` (`WORM_ENV` or `Environment.development`), `currentTransaction` (`null`), `registeredConnections` (empty list), `observersFor` (empty list), `mutedEvents` (`null`), `isMutingAll` (`false`), `isEventMuted` |
| Safe, acts normally | `unsafe`, `withoutEvents`, `isUnsafe`, `seedRandom`, `reset` (no-op), `rollbackTestTransaction` (no-op) |

## Lifecycle

### initialize

**Signature**

```dart
static Future<void> initialize({
  required WormConfig config,
  required Map<String, DatabaseAdapter> adapters,
  List<ModelRegistration> models = const <ModelRegistration>[],
  List<Observer<Object>> observers = const <Observer<Object>>[],
})
```

**Example**

```dart
await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': InMemoryAdapter()},
  models: [const ModelRegistration(type: User, tableName: 'users')],
);
```

Registers each `adapters` entry under its connection name, stores `models` keyed by Dart type, stores `observers`, then calls `connect()` on every adapter.

**Gotchas**

- Calling `initialize` twice without `reset` throws `ConfigurationException` with key `'initialization.duplicate'`.
- If `adapters` has no entry for `config.defaultConnection`, it throws `ConfigurationException` with key `'adapter.missing'` before registering anything.
- Adapters are connected in map iteration order; a failing `connect()` propagates.

**Related:** [reset](#reset), [configuration options](./configuration-options.md), [multiple connections](../database/multiple-connections.md)

### reset

**Signature**

```dart
static Future<void> reset()
```

**Example**

```dart
tearDown(Worm.reset);
```

Returns the runtime to its uninitialized state: rolls back any active test transaction, disconnects all adapters, clears models, observers, the morph registry, and the config.

**Gotchas**

- Intended for tests. It is safe to call when nothing is initialized (no-op).
- `reset` calls `disconnect()` on adapters, not `close()`; an `InMemoryAdapter` keeps its data until `close()` is called or the instance is garbage collected.

**Related:** [initialize](#initialize), [testing guide](../guides/testing.md)

### isInitialized

**Signature**

```dart
static bool get isInitialized
```

**Example**

```dart
if (!Worm.isInitialized) {
  await bootstrapWorm();
}
```

`true` after `initialize` succeeds and until `reset` completes. Useful as a health-check probe.

**Gotchas**

- Always safe to read; never throws.

**Related:** [initialize](#initialize), [production guide](../guides/production.md)

## Registry lookups

### config

**Signature**

```dart
static WormConfig get config
```

**Example**

```dart
final defaultConn = Worm.config.defaultConnection; // 'default'
```

**Gotchas**

- Throws `ConfigurationException('initialization')` before `initialize`.

**Related:** [configuration options](./configuration-options.md)

### adapter

**Signature**

```dart
static DatabaseAdapter adapter([String? connection])
```

**Example**

```dart
final main = Worm.adapter();            // default connection
final logs = Worm.adapter('analytics'); // named connection
```

Resolution order: an active test-transaction handle (default connection only), then the ambient `Worm.transaction` context on the same connection, then the registered adapter map.

**Gotchas**

- Throws `ConfigurationException('initialization')` before `initialize` and `ConfigurationException('adapter.unknown')` for an unregistered name.
- Inside `Worm.transaction`, `adapter()` transparently returns the transactional handle for that connection. This is what makes saves auto-enlist.

**Related:** [transaction](#transaction), [adapter API](./adapter-api.md), [multiple connections](../database/multiple-connections.md)

### registrationOf

**Signature**

```dart
static ModelRegistration registrationOf<T>()
```

**Example**

```dart
final reg = Worm.registrationOf<User>();
print(reg.tableName); // 'users'
```

**Gotchas**

- Throws `ConfigurationException('model.unknown')` when `T` was not passed to `initialize`.

**Related:** [registrationForType](#registrationfortype), [defining models](../models/defining-models.md)

### registrationForType

**Signature**

```dart
static ModelRegistration registrationForType(Type type)
```

**Example**

```dart
final reg = Worm.registrationForType(user.runtimeType);
```

Same lookup as `registrationOf`, keyed by a runtime `Type` value instead of a type parameter.

**Gotchas**

- Throws `ConfigurationException('model.unknown')` for unregistered types.

**Related:** [registrationOf](#registrationof)

### models

**Signature**

```dart
static List<ModelRegistration> get models
```

**Example**

```dart
for (final reg in Worm.models) {
  print('${reg.type} -> ${reg.tableName}');
}
```

**Gotchas**

- Returns an unmodifiable view; mutating it throws at runtime.
- Throws `ConfigurationException('initialization')` before `initialize`.

**Related:** [defining models](../models/defining-models.md)

### registeredConnections

**Signature**

```dart
static List<String> get registeredConnections
```

**Example**

```dart
print(Worm.registeredConnections); // ['default', 'analytics']
```

**Gotchas**

- Safe before `initialize`: returns an empty unmodifiable list rather than throwing.

**Related:** [adapter](#adapter), [multiple connections](../database/multiple-connections.md)

### observers

**Signature**

```dart
static List<Observer<Object>> get observers
```

**Example**

```dart
final all = Worm.observers; // registration order
```

**Gotchas**

- Throws `ConfigurationException('initialization')` before `initialize`.
- Order matters: observers fire in registration order during lifecycle dispatch.

**Related:** [observersFor](#observersfor), [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md)

### observersFor

**Signature**

```dart
static List<Observer<Object>> observersFor(Type type)
```

**Example**

```dart
final userObservers = Worm.observersFor(User);
```

**Gotchas**

- Safe before `initialize`: returns an empty unmodifiable list rather than throwing.

**Related:** [observers](#observers), [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md)

### morphRegistry

**Signature**

```dart
static MorphRegistry get morphRegistry
```

**Example**

```dart
Worm.morphRegistry.register(
  MorphRegistration<Post>(
    morphType: 'post',
    type: Post,
    table: 'posts',
    hydrate: PostHydration.fromRow,
  ),
);
```

Process-wide mapping between polymorphic type strings (for example `'post'`) and Dart model types. `reset()` clears it.

**Gotchas**

- Throws `ConfigurationException('initialization')` before `initialize`.
- Registering a duplicate morph type string or Dart type throws `ConfigurationException` with keys `'morph.duplicate.type'` or `'morph.duplicate.dart'`.
- `morphNameFor(Type)` throws `ConfigurationException('morph.unknown')` for unregistered types; `morphTypeFor(Type)` and `typeFor(String)` return `null` instead.

**Related:** [polymorphic relations](../relations/polymorphic-relations.md)

## Strictness and the escape hatch

### strictness

**Signature**

```dart
static StrictnessConfig get strictness
```

**Example**

```dart
if (Worm.strictness.preventFullTableScans) {
  // a WHERE-less query will throw
}
```

Returns `WormConfig.strictness` when initialized, otherwise the all-off default `StrictnessConfig`.

**Gotchas**

- Safe before `initialize` by design: strictness gates rely on the all-off fallback so code stays usable in tests that never boot the runtime.

**Related:** [strict mode guide](../guides/strict-mode.md), [configuration options](./configuration-options.md#strictnessconfig)

### isUnsafe

**Signature**

```dart
static bool get isUnsafe
```

**Example**

```dart
assert(!Worm.isUnsafe);
await Worm.unsafe(() async {
  assert(Worm.isUnsafe);
});
```

**Gotchas**

- Reads only Zone state; safe anywhere, anytime.

**Related:** [unsafe](#unsafe)

### unsafe

**Signature**

```dart
static Future<T> unsafe<T>(Future<T> Function() body)
```

**Example**

```dart
// Deliberate full-table delete under strict mode.
await Worm.unsafe(() async {
  await User.query().delete();
});
```

Runs `body` with every global strictness gate disabled: `preventFullTableScans`, `preventLazyLoading`, `preventDestructiveWithoutWhere`, and the global `preventSilentMassAssignment` policy. The flag propagates via a Dart Zone, so it survives `await`s inside `body` and restores automatically when `body` returns or throws.

**Gotchas**

- Per-model `strictMassAssignment` overrides are not relaxed; only the global policy is.
- Nesting is a no-op: entering an already-unsafe zone changes nothing.
- Inside `unsafe`, `Model.getRelation` returns `null` for unloaded relations instead of throwing.

**Related:** [strict mode guide](../guides/strict-mode.md), [mass assignment](../models/mass-assignment.md)

## Transactions

### transaction

**Signature**

```dart
static Future<T> transaction<T>(
  Future<T> Function(TransactionContext txn) action, {
  String? connection,
})
```

**Example**

```dart
await Worm.transaction((txn) async {
  await user.save();          // auto-enlists via the ambient context
  await txn.savepoint(() async {
    await post.save();        // nested rollback boundary
  });
});
```

Opens a transaction on `connection` (the default connection when omitted), hands a `TransactionContext` to `action`, and commits when it returns, draining every deferred `afterCommit` callback. Throwing from `action` rolls back, discards those callbacks, and rethrows.

**Gotchas**

- A nested `Worm.transaction` on the same connection joins the enclosing one (no second `BEGIN`). Use `txn.savepoint(...)` for a real nested rollback boundary.
- A nested `Worm.transaction` on a different connection opens its own independent transaction.
- Throws `UnsupportedOperationException` when the resolved adapter's `capabilities.supportsTransactions` is `false`. The MongoDB adapter throws `TransactionException` by design: it does not support multi-document transactions.
- Throws `ConfigurationException('initialization')` before `initialize`.

**Related:** [transactions](../database/transactions.md), [currentTransaction](#currenttransaction), [adapter API](./adapter-api.md)

### currentTransaction

**Signature**

```dart
static TransactionContext? get currentTransaction
```

**Example**

```dart
final txn = Worm.currentTransaction;
if (txn != null) print('inside ${txn.connectionName}');
```

Resolves the ambient `Worm.transaction` context from the Zone, falling back to an active test-transaction context, else `null`.

**Gotchas**

- Safe before `initialize`; returns `null`.

**Related:** [transaction](#transaction), [beginTestTransaction](#begintesttransaction)

### beginTestTransaction

**Signature**

```dart
static Future<void> beginTestTransaction()
```

**Example**

```dart
setUp(Worm.beginTestTransaction);
tearDown(Worm.rollbackTestTransaction);
```

Opens a transaction on the default adapter and keeps it open. While active, every `Worm.adapter()` call for the default connection returns the transactional handle, so all writes during the test are isolated.

**Gotchas**

- For test use only. It mutates global static state on `Worm` and is not safe for concurrent production use.
- Affects only the default connection; writes on named connections are not isolated.
- Throws `ConfigurationException('test_transaction.duplicate')` when a test transaction is already active.
- Throws `ConfigurationException('initialization')` before `initialize`.

**Related:** [rollbackTestTransaction](#rollbacktesttransaction), [testing guide](../guides/testing.md)

### rollbackTestTransaction

**Signature**

```dart
static Future<void> rollbackTestTransaction()
```

**Example**

```dart
await Worm.rollbackTestTransaction();
```

Rolls back the active test transaction and waits for the adapter to fully unwind, so callers immediately observe pre-test state.

**Gotchas**

- No-op when no test transaction is active; safe to call unconditionally (and before `initialize`).
- Deferred `afterCommit` callbacks queued during the test are discarded, never fired.
- `Worm.reset()` calls this automatically.

**Related:** [beginTestTransaction](#begintesttransaction), [testing guide](../guides/testing.md)

## Lifecycle events

### withoutEvents

**Signature**

```dart
static Future<T> withoutEvents<T>(
  Future<T> Function() body, {
  List<LifecycleEvent>? events,
})
```

**Example**

```dart
// Mute everything:
await Worm.withoutEvents(() async => user.save());

// Mute only afterSave:
await Worm.withoutEvents(
  () async => user.save(),
  events: [LifecycleEvent.afterSave],
);
```

With no `events`, every lifecycle event is muted for the duration of `body`. With an explicit list, only those events are skipped, unioned with any events already muted by an enclosing `withoutEvents`.

**Gotchas**

- Muting suppresses model hooks and observers only. Validation still runs; it is a correctness gate, not an event.
- If an enclosing `withoutEvents` already mutes everything, a nested call with an explicit list still mutes everything.
- Zone-propagated: survives `await`s inside `body`.

**Related:** [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md), [isEventMuted](#iseventmuted)

### mutedEvents

**Signature**

```dart
static Set<LifecycleEvent>? get mutedEvents
```

**Example**

```dart
final muted = Worm.mutedEvents; // {LifecycleEvent.afterSave} or null
```

**Gotchas**

- Returns `null` both when nothing is muted and when everything is muted. Check `isMutingAll` to distinguish.
- Safe anywhere; reads only Zone state.

**Related:** [isMutingAll](#ismutingall), [withoutEvents](#withoutevents)

### isMutingAll

**Signature**

```dart
static bool get isMutingAll
```

**Example**

```dart
await Worm.withoutEvents(() async {
  assert(Worm.isMutingAll);
});
```

**Gotchas**

- `true` only for the mute-everything form of `withoutEvents`; an explicit `events:` list leaves it `false`.

**Related:** [mutedEvents](#mutedevents)

### isEventMuted

**Signature**

```dart
static bool isEventMuted(LifecycleEvent event)
```

**Example**

```dart
if (!Worm.isEventMuted(LifecycleEvent.beforeDelete)) {
  // hook will fire
}
```

**Gotchas**

- Safe before `initialize`; reads only Zone state.

**Related:** [withoutEvents](#withoutevents), [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md)

## Miscellaneous

### seedRandom

**Signature**

```dart
static void seedRandom(int seed)
```

**Example**

```dart
Worm.seedRandom(42);
final u1 = await UserFactory().create(); // deterministic fake data
```

Forwards to `FakerService.seed` so factory data is reproducible across runs with the same seed.

**Gotchas**

- Seeds the shared singleton; every factory in the process draws from the same stream.
- Safe before `initialize`.

**Related:** [factories](../models/factories.md), [seeding](../database/seeding.md)

### environment

**Signature**

```dart
static Environment get environment
```

**Example**

```dart
if (Worm.environment == Environment.production) {
  // destructive CLI commands require --force here
}
```

Reads the `WORM_ENV` process environment variable first (trimmed, case-insensitive match against `Environment` value names). Falls back to `WormConfig.environment`, then to `Environment.development`.

**Gotchas**

- `WORM_ENV` silently overrides the config value; an unparseable value falls through to config.
- Safe before `initialize`.

**Related:** [configuration options](./configuration-options.md#environment), [production guide](../guides/production.md)

## Continue reading

- [Configuration options](./configuration-options.md) for every field on `WormConfig`, `ConnectionConfig`, and `StrictnessConfig`.
- [Strict mode guide](../guides/strict-mode.md) for what each strictness gate throws and when.
- [Transactions](../database/transactions.md) for savepoints, `afterCommit`, and nesting semantics in depth.
- [Exceptions](./exceptions.md) for the full `ConfigurationException` key catalog.
