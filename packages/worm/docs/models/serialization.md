---
title: Serialization
description: Render models to JSON-safe maps with hidden fields, computed attributes, and cycle-safe relation graphs.
---

This page shows how to turn models into maps and JSON strings, hide sensitive fields, append computed values, and serialize relation graphs without infinite loops. It builds on [defining models](./defining-models.md).

## toMap and toJson

Every model gets `toMap()` and `toJson()`:

```dart
final map = user.toMap();
// {'id': 'u-1', 'name': 'Alice', 'created_at': ...}

final json = user.toJson();
// '{"id":"u-1","name":"Alice",...}'
```

`toMap` takes four optional parameters:

```dart
user.toMap(
  only: {'id', 'name'},        // whitelist, applied last, top level only
  hidden: {'internal_flag'},   // extra keys to drop for this call
  includeRelations: true,      // walk relations via the cycle-aware Serializer
  maxDepth: 2,                 // nesting budget when relations are included
);
```

`toJson()` takes no parameters and defers to `toMap()` with its defaults, so it never includes relations. When you need relation output as JSON, encode it yourself:

```dart
final json = jsonEncode(user.toMap(includeRelations: true));
```

Serialization reads live attribute values through `toRow()`. [Casts](./casts.md) are not re-applied here; they belong to the storage boundary.

## The describe() pipeline

Under the hood, both `toMap` and the standalone `Serializer` consume one thing: the `SerializationDescriptor` returned by `describe()`. The base implementation is:

```dart
@override
SerializationDescriptor describe() => SerializationDescriptor(
  fields: toRow(),
  hidden: hiddenFromSerialization,
  appended: computedAttributes,
);
```

`describe()` is the supported customization point. Overriding `toMap` directly is unsupported: the `Serializer` pipeline reads `describe()`, not `toMap`, and the two would drift apart.

## Hiding fields

Override `hiddenFromSerialization` to drop fields from every `toMap` and `toJson` call:

```dart title="user.dart"
final class User extends Model {
  // ... constructor, id, toRow ...

  @override
  Set<String> get hiddenFromSerialization => const {'password_hash'};
}
```

Hidden fields still exist on the model and still reach the database through `toRow()`. They just never appear in serialized output. For a one-off exclusion, pass `hidden:` to `toMap`; for a one-off whitelist, pass `only:`.

## Computed attributes

Override `computedAttributes` to append values that don't correspond to a database column:

```dart title="user.dart"
final class User extends Model {
  // ... constructor, id, toRow ...

  String get name => getAttribute('name')! as String;

  @override
  Map<String, Object?> get computedAttributes => {
    'display_name': '@$name',
  };
}
```

Computed attributes appear in `toMap` and `toJson` output but never in `toRow()`, so they are never written to the database.

## Serializing relations

`toMap(includeRelations: true)` hands the model to the cycle-aware `Serializer`. The serializer walks `SerializationDescriptor.relations`, and here is the catch: the base `describe()` exposes **no relations**. To serialize a relation graph, override `describe()` and list the related objects yourself:

```dart title="user.dart"
final class User extends Model {
  // ... constructor, id, toRow ...

  List<Post> posts = <Post>[];

  @override
  SerializationDescriptor describe() => SerializationDescriptor(
    fields: toRow(),
    hidden: hiddenFromSerialization,
    appended: computedAttributes,
    relations: {'posts': posts},
  );
}
```

Each `relations` value must be a `Serializable` or a `List<Serializable>`; `Model` implements `Serializable`, so models and lists of models qualify. If the relation was populated by [eager loading](../relations/eager-loading.md), read it with `getRelation<T>(name)` inside your override. `getRelation` throws when the relation was never loaded, so only expose relations you know are loaded on that code path.

### Cycles collapse to references

The serializer caches every fully serialized node by `type#id`. When it meets the same node again, through a cycle or through a second path in the graph, it emits a reference instead of recursing:

```dart
final serialized = user.toMap(includeRelations: true);
// posts[0].author collapses to:
// {'type': 'User', 'id': 'u-1', 'ref': true}
```

Hidden fields never leak through a reference, but the `type` and `id` do, by design. If your ids are sensitive, treat serialized output accordingly. See [security](../guides/security.md).

### The depth budget

`maxDepth` caps how many nested relation levels the serializer walks. `Model.toMap` defaults to `maxDepth: 2`. Once the budget is spent, deeper relations are omitted from the output entirely: their keys don't appear at all. With `maxDepth: 0`, no relations are walked.

## The standalone Serializer

You can serialize anything that implements `Serializable`, not just models:

```dart
const serializer = Serializer(); // maxDepth defaults to 8
final map = serializer.toMap(user);
final json = serializer.toJson(user);
```

`Serializable` requires three members: `serializationId` (cycle-detection identity), `serializationType` (the type tag in references), and `describe()`. On `Model`, `serializationId` is `'$id'` and `serializationType` is the runtime type name.

`SerializationDescriptor` also carries a `visible` whitelist. When non-null, only the listed keys appear, minus anything in `hidden`. The whitelist applies to fields, appended values, and relation keys alike. `Model.describe()` never sets `visible`; the model-level whitelist is `toMap(only: ...)`, which is applied after serialization and only at the top level.

```dart
SerializationDescriptor(
  fields: {'id': id, 'name': name, 'password': password},
  hidden: const {'password'},
  visible: const {'id', 'name', 'display_name'},
  appended: {'display_name': '@$name'},
  relations: {'posts': posts},
);
```

## Gotchas

- Override `describe()`, never `toMap()`. The `Serializer` reads `describe()`, so a `toMap` override diverges the two outputs.
- `toJson()` takes no parameters. It never includes relations; use `jsonEncode(toMap(includeRelations: true))` for that.
- The base `describe()` exposes no relations, so `toMap(includeRelations: true)` yields no relation keys until you override `describe()`.
- Collapsed references leak `type` and `id` by design, even for nodes whose fields are hidden.
- Relations beyond `maxDepth` are dropped from the output, not truncated to references. Missing keys, not `ref` markers.
- `Model.toMap` defaults to `includeRelations: false` and `maxDepth: 2`; the standalone `Serializer` defaults to `maxDepth: 8`.
- `only:` and `hidden:` on `toMap` apply after serialization and only to top-level keys. They don't reach into nested relation maps.
- `visible` exists on `SerializationDescriptor`, but `Model.describe()` never sets it. Set it yourself in a `describe()` override if you want a descriptor-level whitelist.
- Casts are not applied during serialization. A `Decimal` field serializes as whatever value the attribute currently holds.
- `getRelation` throws `RelationNotLoadedException` (or `LazyLoadingException` under strict mode) for unloaded relations. Guard your `describe()` override on code paths where the relation may not be loaded.

## API summary

| Symbol | Signature sketch | Description |
| --- | --- | --- |
| `Serializable` | `abstract; String get serializationId; String get serializationType; SerializationDescriptor describe()` | Contract for anything the `Serializer` can render. `Model` implements it. |
| `SerializationDescriptor` | `const SerializationDescriptor({required Map<String, Object?> fields, Set<String> hidden = {}, Set<String>? visible, Map<String, Object?> appended = {}, Map<String, Object> relations = {}})` | Value snapshot of what to expose. `relations` values are `Serializable` or `List<Serializable>`. |
| `Serializer` | `const Serializer({int maxDepth = 8})` | Cycle-aware graph renderer with a depth budget. |
| `Serializer.toMap` | `Map<String, Object?> toMap(Serializable root)` | Render the graph to a JSON-shaped map. |
| `Serializer.toJson` | `String toJson(Serializable root)` | Render the graph to a JSON string. |
| `Model.toMap` | `toMap({Set<String>? only, Set<String>? hidden, bool includeRelations = false, int maxDepth = 2})` | Serialize one model, optionally walking relations. |
| `Model.toJson` | `String toJson()` | `jsonEncode(toMap())`; no parameters, no relations. |
| `Model.describe` | `SerializationDescriptor describe()` | The supported customization point for serialized shape. |
| `Model.hiddenFromSerialization` | `Set<String> get hiddenFromSerialization` | Field names dropped from every serialization. |
| `Model.computedAttributes` | `Map<String, Object?> get computedAttributes` | Extra values appended to output, never written to the database. |
| `Model.serializationId` | `String get serializationId` | Cycle-detection identity; defaults to `'$id'`. |
| `Model.serializationType` | `String get serializationType` | Type tag in collapsed references; defaults to the runtime type name. |

## Continue reading

- [Casts](./casts.md): the storage boundary, where values are converted on read and write.
- [Eager loading](../relations/eager-loading.md): how relations get loaded before you serialize them.
- [Security](../guides/security.md): hidden fields, leaking ids, and what serialized output reveals.
