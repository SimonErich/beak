---
title: Mass assignment
description: Control which fields fill() and update() may write, and choose between silent skipping and strict exceptions.
---

Mass assignment is writing many attributes from one map, typically straight from request input. Worm guards it with two model overrides and an optional strict mode. This page builds on [saving and updating](./saving-and-updating.md).

## What counts as mass assignment

Two methods are guarded: `fill(map)` and `update(map)`, which is `fill` followed by `save`.

```dart
final user = User();
user.fill({'name': 'Ada', 'email': 'ada@example.com'});

await user.update({'name': 'Ada Lovelace'});
```

Direct assignment via `setAttribute(name, value)` is never guarded. The protection targets untrusted maps, not your own code.

## fillable and guarded

The canonical mechanism is a pair of `Model` overrides:

```dart title="lib/models/user.dart"
final class User extends Model {
  // ... constructor, id, toRow ...

  @override
  List<String> get fillable => const ['name', 'email'];

  @override
  List<String> get guarded => const ['role'];
}
```

For each key in the map, `fill` decides in this order:

1. If the key is in `guarded`, it is rejected. `guarded` always wins.
2. If `fillable` is empty, the key is accepted. An empty whitelist means "everything is fillable".
3. Otherwise the key must appear in `fillable`.

The defaults are an empty `fillable` and an empty `guarded`, so a fresh model accepts every key.

:::note[Annotations vs overrides]
`@Fillable` and `@Guarded` annotations exist, but they are experimental: the generator emits the matching getter overrides only into an opt-in `_$<Model>Annotations` mixin, and nothing changes unless you mix that in yourself. The overrides are the mechanism the runtime reads. When writing models by hand, or when in doubt, override the getters directly. See [annotations](../reference/annotations.md).
:::

## Silent skip vs strict throw

By default, rejected keys are **silently skipped**. Accepted keys in the same map are still applied and marked dirty. This is forgiving, but it also means a typo in a key name disappears without a trace.

Strict mode turns the skip into an exception. Enable it per model:

```dart
@override
bool get strictMassAssignment => true;
```

Or globally, for every model, via the strictness config:

```dart
await Worm.initialize(
  config: const WormConfig(
    strictness: StrictnessConfig(preventSilentMassAssignment: true),
  ),
  adapters: {'default': adapter},
);
```

In strict mode, `fill` collects **every** offending key and throws one `MassAssignmentException` reporting all of them:

```dart
try {
  user.fill({'name': 'Ada', 'role': 'admin', 'is_admin': true});
} on MassAssignmentException catch (e) {
  print(e.fields); // [role, is_admin]
}
```

`e.fields` lists every offending key. `e.field` holds only the first one and exists for backwards compatibility; prefer `fields`.

## The escape hatch: Worm.unsafe

`Worm.unsafe` disables the **global** strictness gates for the wrapped region. Inside it, a model without its own strict flag falls back to silent skipping even when `preventSilentMassAssignment` is on:

```dart
await Worm.unsafe(() async {
  user.fill({'name': 'Ada', 'role': 'admin'}); // 'role' skipped, not thrown
});
```

The flag rides on a Dart Zone, so it survives `await`s inside the callback and resets automatically afterwards. Two limits apply: `unsafe` does not bypass a model's own `strictMassAssignment` override, and it never makes guarded keys fillable. They are still skipped.

## Gotchas

- `setAttribute` bypasses mass-assignment protection entirely. Guarding applies to `fill` and `update` only.
- In the default silent mode, a misspelled key vanishes without an error. Turn on `preventSilentMassAssignment` in production; see [strict mode](../guides/strict-mode.md).
- A strict `fill` applies the permitted keys **before** it throws. The exception reports the rejected keys; the accepted ones are already assigned and dirty.
- `update(map)` runs `fill` first, so it can throw `MassAssignmentException` before any query executes.
- `Worm.unsafe` relaxes only the global flag. A model that overrides `strictMassAssignment => true` still throws inside an `unsafe` block.
- An empty `fillable` means everything is fillable, not nothing. To lock a model down, list its writable fields explicitly.

## Continue reading

- [Security](../guides/security.md): strict mass assignment as the first line of defense for request input.
- [Strict mode](../guides/strict-mode.md): the full `StrictnessConfig` flag set and when to enable each.
- [Saving and updating](./saving-and-updating.md): what happens to filled attributes on the next `save()`.
- [Annotations](../reference/annotations.md): the experimental `@Fillable` / `@Guarded` annotation forms.
