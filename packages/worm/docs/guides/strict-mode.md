---
title: Strict mode
description: Every StrictnessConfig flag, the exact exception it throws, and the Worm.unsafe escape hatch.
---

Strict mode is a set of independent guardrails you flip on through `StrictnessConfig`. This page walks every flag, names the exact exception each one throws, and explains the `Worm.unsafe` escape hatch. Think of the flags as the bird's guardrails: each one catches a different way of falling out of the nest.

## Enabling strict mode

All flags default to `false`. You enable them per flag on the config you hand to `Worm.initialize`; flags are orthogonal, so flipping one never flips another:

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(
      preventLazyLoading: true,
      preventFullTableScans: true,
      preventSilentMassAssignment: true,
    ),
  ),
  adapters: {'default': adapter},
);
```

Four of the knobs (`warnOnN1Queries`, `throwOnN1Queries`, `warnOnMissingIndex`, and `slowQueryThreshold`) are enforced by the `LoggingAdapter`, which carries its own `StrictnessConfig` and must wrap your adapter explicitly. See [logging and debugging](./logging-and-debugging.md) for the wiring.

## Flag by flag

### preventLazyLoading

Worm has no lazy loading by design. Accessing a relation that was not eagerly loaded always fails; this flag changes how it fails. Without the flag, `getRelation` throws `RelationNotLoadedException`. With the flag, it throws `LazyLoadingException` instead, signaling a deliberate policy violation rather than an accident:

```dart
final post = await Post.query().firstOrFail();
post.getRelation<User>('author'); // throws: relation not loaded
```

The fix is the same either way, an eager load:

```dart
final post = await Post.query()
    .withRelationPaths(['author'])
    .firstOrFail();
final author = post.getRelation<User>('author'); // loaded
```

Inside `Worm.unsafe`, the same access returns `null` instead of throwing. See [eager loading](../relations/eager-loading.md).

### preventFullTableScans

Throws `FullTableScanException` when a query would run without a `WHERE` clause. This is the umbrella flag for "do not touch every row": it blocks WHERE-less reads and also blocks WHERE-less destructive writes, even when `preventDestructiveWithoutWhere` is off.

```dart
await User.query().get(); // throws FullTableScanException under the flag
await User.query().where(User$.active.eq(true)).get(); // fine
```

### preventDestructiveWithoutWhere

Throws `FullTableScanException` when a bulk `update()` or `delete()` runs without a `WHERE` clause. Narrower than `preventFullTableScans`: reads stay unrestricted.

```dart
await Post.query().delete(); // throws under either flag
await Post.query().where(Post$.draft.eq(true)).delete(); // fine
```

### preventSilentMassAssignment

Throws `MassAssignmentException` from `fill()` (and `update()`, which fills first) when the data map contains guarded or non-fillable keys. Without the flag those keys are silently skipped. The exception collects every offending key in `.fields`. See [mass assignment](../models/mass-assignment.md).

### warnOnN1Queries

Logs a `[WARNING]` line when the N+1 detector sees 5 or more single-row lookups against the same table within 100 ms. Warning only, nothing throws. Requires the `LoggingAdapter` wrap; without it the flag has no effect.

### throwOnN1Queries

Escalates the same detection to a thrown `DangerousQueryException` carrying the offending table name. `DangerousQueryException` is a typedef of `FullTableScanException`, so a `catch` on either name catches both. Either N+1 flag alone arms the detector; when the throw flag is set, no warning line is emitted first. Also `LoggingAdapter`-enforced.

### warnOnMissingIndex

Logs a structured `missing-index` warning when a filtered query's EXPLAIN plan reports no index use. Only works against adapters that declare `supportsExplain` and mix in `ExplainCapable`; against anything else the check is a silent no-op. Warning only, never throws.

### slowQueryThreshold

A `Duration`, default 500 milliseconds. Queries at or above it trigger the `QueryLogger.slowQuery` callback from the `LoggingAdapter`. This is a different knob from `LogConfig.slowQueryThreshold` (default 200 ms), which only controls whether a log line gets the `[SLOW QUERY]` prefix instead of `[QUERY]`. The two thresholds are independent and both active.

## Flag to exception map

| Flag | Enforced by | Effect |
| --- | --- | --- |
| `preventLazyLoading` | `Model.getRelation` | Throws `LazyLoadingException` (instead of `RelationNotLoadedException`) |
| `preventFullTableScans` | `QueryBuilder` | Throws `FullTableScanException` on WHERE-less queries, reads and writes |
| `preventDestructiveWithoutWhere` | `QueryBuilder` | Throws `FullTableScanException` on WHERE-less `update()`/`delete()` |
| `preventSilentMassAssignment` | `Model.fill` | Throws `MassAssignmentException` |
| `warnOnN1Queries` | `LoggingAdapter` | Logs `[WARNING]` on detected N+1 pattern |
| `throwOnN1Queries` | `LoggingAdapter` | Throws `DangerousQueryException` (typedef of `FullTableScanException`) |
| `warnOnMissingIndex` | `LoggingAdapter` | Logs `missing-index` warning when EXPLAIN shows no index |
| `slowQueryThreshold` | `LoggingAdapter` | Invokes `QueryLogger.slowQuery` at or above the duration (default 500 ms) |

Every exception's fields and hierarchy live in the [exceptions reference](../reference/exceptions.md).

## The Worm.unsafe escape hatch

`Worm.unsafe` runs a callback with the query and model gates relaxed. The flag propagates through a Dart Zone, so it survives `await`s inside the body and restores automatically when the body returns or throws:

```dart
final removed = await Worm.unsafe(() async {
  // Deliberate full-table delete. Strict mode would block this.
  return Post.query().delete();
});
```

What `unsafe` relaxes, precisely:

- The full-table-scan guard and the destructive-write guard. `QueryBuilder` checks `Worm.isUnsafe` before throwing.
- Unloaded relation access. `getRelation` returns `null` instead of throwing, so you can probe for loaded relations.
- The global `preventSilentMassAssignment` flag. `fill()` falls back to silent skipping inside the zone.

What `unsafe` does not relax:

- A model's own `strictMassAssignment` override. The per-model opt-in throws even inside `unsafe`.
- Validation. Rules still run on save.
- The `LoggingAdapter` checks: N+1 warnings and throws, missing-index warnings, and slow-query callbacks fire regardless.

Nested `unsafe` calls are idempotent; entering an already-unsafe zone is a no-op. You can check the current state with `Worm.isUnsafe`.

## Per-builder and global config

Strictness applies at two levels. The global level is `WormConfig.strictness`, read through `Worm.strictness` (safe to call before `initialize`; it falls back to all-off defaults). The local level is the `StrictnessConfig` a builder carries from construction: `QueryBuilder.from(context, strictness: ...)`. The effective gate is an OR: a check runs when either the builder's local config or the global config enables it. Generated `query()` starters pass no local config, so in practice the global config governs, and the local parameter matters for hand-built builders and tests.

## Recommended profiles

- Development: `warnOnN1Queries: true`, `warnOnMissingIndex: true`, everything else off. You want noise, not crashes.
- Production: `preventLazyLoading`, `preventFullTableScans`, `preventSilentMassAssignment`, `preventDestructiveWithoutWhere` all on; keep the N+1 flags as warnings unless you have verified your hot paths.
- Bulk jobs and perf suites: keep `throwOnN1Queries` off. Bulk write patterns can look like N+1 to the detector and would abort mid-job.

## Gotchas

- `warnOnN1Queries`, `throwOnN1Queries`, `warnOnMissingIndex`, and `slowQueryThreshold` do nothing unless the adapter is wrapped in a `LoggingAdapter`, and that wrapper's own `strictness` argument is what those checks read.
- `preventFullTableScans` also blocks destructive writes without WHERE. Enabling only it still gates `update()`/`delete()`.
- There are two slow-query thresholds: `StrictnessConfig.slowQueryThreshold` (500 ms, callback) and `LogConfig.slowQueryThreshold` (200 ms, line prefix). They do not share a value.
- `DangerousQueryException` and `FullTableScanException` are the same class under two names.
- `Worm.unsafe` does not silence the N+1 throw. A bulk job that trips the detector fails even inside an unsafe zone; turn `throwOnN1Queries` off for that workload instead.
- Builders created before `Worm.initialize` are still guarded: the effective check merges the local config with the live global one at execution time.

## Continue reading

- [Exceptions reference](../reference/exceptions.md) for the full hierarchy and every typed field.
- [Configuration options](../reference/configuration-options.md) for `StrictnessConfig` in table form.
- [Logging and debugging](./logging-and-debugging.md) for wiring the `LoggingAdapter` that enforces the N+1 and index checks.
- [Production](./production.md) for where strict mode fits in a deploy checklist.
