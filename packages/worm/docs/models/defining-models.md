---
title: Defining models
description: How to declare a worm model, wire its table mapping, and register it with the runtime.
---

This page shows you how to declare a model class, what the `Model` base class requires from you, and how worm resolves table names, connections, and primary keys. It is the hub for everything else in this section.

## Anatomy of a model

A worm model is a Dart class that extends `Model`. Annotations describe the table mapping for the [code generator](./code-generation.md); the `Model` base class provides persistence, dirty tracking, timestamps, and lifecycle hooks at runtime.

```dart title="lib/models/user.dart"
import 'package:worm/worm.dart';

part 'user.g.dart';

@Table(name: 'users')
final class User extends Model {
  User({required this.id, required this.name, required this.age});

  @PrimaryKey()
  @Column()
  @override
  final String id;

  @Column()
  final String name;

  @Column()
  final int age;

  @override
  Map<String, Object?> toRow() => {'id': id, 'name': name, 'age': age};
}
```

Run `dart run worm:worm gen` and the generator emits a typed companion (`User$`), a `fromRow` hydrator, and a query starter into the `user.g.dart` part file. [Code generation](./code-generation.md) walks through every artifact.

Three details in this example matter:

- The constructor takes one named parameter per `@Column` field. The generated `fromRow` calls `User(id: ..., name: ..., age: ...)`, so the parameter names must match the field names.
- The `id` field carries both `@PrimaryKey()` and `@Column()`. Only `@Column` fields become columns in the generated code; a bare `@PrimaryKey()` is skipped.
- `toRow()` is written by hand. It is an abstract member of `Model`, and the generated `toRow` extension cannot satisfy an abstract instance member.

## Required overrides

`Model` has exactly two abstract members. Every model must provide them:

| Override | Purpose |
|---|---|
| `Object get id` | The primary key value. A `final String id` field satisfies it. |
| `Map<String, Object?> toRow()` | Serializes the model to a database row. Consumed by `save()`, the query builder, and the serializer. |

Worm does not generate primary key values for you. You assign `id` yourself (or let the database do it with an auto-increment column). `PrimaryKeyType.uuid` and `PrimaryKeyType.integer` on `ModelRegistration` describe the strategy for schema tooling; they do not mint ids at save time.

## The attribute store

Every model instance owns an attribute store: a map of column name to value with dirty tracking on top. It is the source of truth for updates and refreshes.

```dart
user.setAttribute('name', 'Bob');   // write + mark dirty
user.getAttribute('name');          // read the live value
user.isDirty('name');               // true
user.getOriginal('name');           // value at the last save, or null
```

You can define models in two styles, and both are first-class:

- **Field-backed models** (the example above). Typed `final` fields hold the data, `toRow()` reads them, and the attribute store carries changes made through `setAttribute` or `update(...)`. This is the shape the generated `fromRow` constructs.
- **Store-backed models**. All data lives in the attribute store, and typed getters read from it. See the "Working without codegen" section below.

Two more methods matter when you hydrate rows yourself:

- `hydrateAttribute(name, value)` seeds a value without marking it dirty.
- `markPersisted()` snapshots the current attributes as the original values and flips `exists` to `true`, so the next `save()` issues an UPDATE instead of an INSERT.

[Saving and updating](./saving-and-updating.md) covers the full write path and the dirty-tracking rules.

## Annotations that shape the table

Annotations live in `package:worm/annotations.dart` (re-exported from `package:worm/worm.dart`). They are input for the code generator; they carry no runtime behavior of their own.

| Annotation | Signature | Effect |
|---|---|---|
| `@Table` | `Table({String? name, String connection = 'default'})` | Maps the class to a table. `name` defaults to the plural snake_case class name. |
| `@Column` | `Column({String? name, ColumnType? type, bool nullable = false, Object? defaultValue})` | Declares a column. `name` defaults to the snake_case field name. |
| `@PrimaryKey` | `PrimaryKey({String columnName = 'id', PrimaryKeyType type = PrimaryKeyType.uuid})` | Documents the key column and generation strategy. |

:::caution[Runtime key config lives elsewhere]
The current generator does not read `@PrimaryKey`. At runtime the key column comes from the `Model.primaryKeyColumn` override (default `'id'`) and from `ModelRegistration.primaryKeyColumn`. Keep the annotation for intent, but override the getter if your key column is not `id`.
:::

Relation annotations (`@HasMany`, `@BelongsTo`, and friends) are covered in [defining relations](../relations/defining-relations.md). The full annotation catalog, including which annotations are stable and which are experimental, lives in the [annotations reference](../reference/annotations.md).

## Naming conventions

When you omit explicit names, worm derives them:

| Input | Derived name | Rule |
|---|---|---|
| `User` | `users` | Class name to plural snake_case table |
| `BlogPost` | `blog_posts` | Only the last segment pluralizes |
| `userId` (field) | `user_id` | camelCase to snake_case |
| `HTMLContent` (field) | `html_content` | Acronyms stay together |

The pluralizer knows common irregulars (`Person` becomes `people`) and uncountables (`Series` stays `series`). It is English-only. When it guesses wrong, pin the name with `@Table(name: '...')` or `@Column(name: '...')`. The full rule set, including pivot table naming, is in [naming conventions](../reference/naming-conventions.md).

## How table names resolve

At runtime, worm resolves a model's table in a fixed order:

1. The `tableName` override on the model, when it returns a non-null value.
2. The `ModelRegistration` supplied to `Worm.initialize`, keyed by the model's runtime type.
3. Neither found: `ConfigurationException` with key `model.tableName.missing`.

The default `tableName` returns `null`, which defers to the registry. Overriding it makes the model self-contained:

```dart
@override
String get tableName => 'users';
```

Pick one source per model. If you override `tableName`, the registration's `tableName` is ignored for lookups (but still required by the registration itself).

## Registering models

`Worm.initialize` takes a list of `ModelRegistration` entries. Each one tells the runtime which table, connection, and key strategy a model type uses, without reflection:

```dart
await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
  models: [
    const ModelRegistration(type: User, tableName: 'users'),
  ],
);

final user = User(id: 'u-1', name: 'Alice', age: 34);
await user.save();
```

`ModelRegistration` defaults: `primaryKeyColumn: 'id'`, `primaryKeyType: PrimaryKeyType.uuid`, `connection: 'default'`, and `morphName: null` (which makes `effectiveMorphName` fall back to the table name; see [polymorphic relations](../relations/polymorphic-relations.md)).

See [configuration](../start-here/configuration.md) for the full `Worm.initialize` story, including adapters and observers.

## Timestamps

Timestamps are on by default. Every insert sets `created_at` and `updated_at` to `DateTime.now().toUtc()`; every update refreshes `updated_at`. The columns do not need to appear in `toRow()`; worm adds them to the write and seeds them into the attribute store.

You can reshape this per model:

```dart
@override
bool get usesTimestamps => false;          // opt out entirely

@override
String get createdAtColumn => 'inserted_at';  // rename the columns

@override
String get updatedAtColumn => 'changed_at';
```

For a one-off write without touching `updated_at`, use `withoutTimestamps`; see [saving and updating](./saving-and-updating.md#timestamps-and-withouttimestamps).

## Connections

`connectionName` defaults to `'default'`. Point a model at another registered adapter by overriding it, or by setting `@Table(connection: 'analytics')` and mixing in the generated annotations mixin (see [code generation](./code-generation.md#the-annotations-mixin)). Registrations carry the same knob via `ModelRegistration(connection: ...)`. [Multiple connections](../database/multiple-connections.md) covers routing in depth.

## Working without codegen

Codegen is optional. A hand-written model keeps all data in the attribute store and exposes typed getters. This compiles and runs with nothing but `package:worm/worm.dart`:

```dart title="lib/models/invoice.dart"
import 'package:worm/worm.dart';

final class Invoice extends Model {
  Invoice({required String id, required int total}) {
    setAttribute('id', id);
    setAttribute('total', total);
  }

  Invoice.fromRow(Map<String, Object?> row) {
    row.forEach(hydrateAttribute);
    markPersisted();
  }

  @override
  String get tableName => 'invoices';

  @override
  Object get id => getAttribute('id') ?? '';

  int get total => switch (getAttribute('total')) {
    final int value => value,
    _ => 0,
  };

  @override
  Map<String, Object?> toRow() => {
    'id': getAttribute('id'),
    'total': getAttribute('total'),
  };
}
```

What you give up without codegen: the typed `Invoice$` field companions, the generated hydrator and query starter, relation accessors, and a working `replicate()` (the base implementation throws `UnsupportedOperationException` until you override it; see [saving and updating](./saving-and-updating.md#replicating-a-model)).

:::tip[Early-bird tip]
Even a hand-fed bird gets the worm. The hand-written style is a good fit for small internal tools and for models with heavily custom hydration.
:::

## Behavior you configure with overrides

Mass assignment (`fillable`, `guarded`, `strictMassAssignment`), validation (`rules`, `updateRules`), serialization shaping (`hiddenFromSerialization`, `computedAttributes`, `describe()`), and casts (`castManager`) are all `Model` overrides. Each has its own page:

- [Mass assignment](./mass-assignment.md)
- [Validation](./validation.md)
- [Serialization](./serialization.md)
- [Casts](./casts.md)
- [Lifecycle hooks and observers](./lifecycle-hooks-and-observers.md)
- [Soft deletes](./soft-deletes.md)

## Gotchas

- `Worm.initialize` must run before any persistence call. Otherwise you get `ConfigurationException` with key `initialization`.
- Only `@Column`-annotated fields become generated columns. A field with only `@PrimaryKey()` is not hydrated and gets no `Field` constant.
- No table name from either the override or the registry throws `ConfigurationException('model.tableName.missing')`.
- Worm never generates primary key values. Supply `id` yourself or use a database auto-increment column.
- The constructor of a codegen model must accept a named parameter per `@Column` field, or the generated `fromRow` will not compile.
- Annotations have no runtime effect. Runtime behavior comes from `Model` overrides and `ModelRegistration`.
- `replicate()` throws `UnsupportedOperationException` on hand-written models until you override it.
- The naming conventions are English-only. Pin names explicitly for anything the pluralizer would mangle.

## API summary

### Model

| Symbol | Signature | Description |
|---|---|---|
| `id` | `Object get id` | Primary key value. Required override. |
| `toRow` | `Map<String, Object?> toRow()` | Row serialization. Required override. |
| `tableName` | `String? get tableName` | Table override; `null` defers to the registry. |
| `connectionName` | `String get connectionName` | Target connection. Default `'default'`. |
| `primaryKeyColumn` | `String get primaryKeyColumn` | Key column. Default `'id'`. |
| `createdAtColumn` | `String get createdAtColumn` | Default `'created_at'`. |
| `updatedAtColumn` | `String get updatedAtColumn` | Default `'updated_at'`. |
| `usesTimestamps` | `bool get usesTimestamps` | Automatic timestamps. Default `true`. |
| `fillable` | `List<String> get fillable` | Mass-assignment whitelist. Empty means everything is fillable. See [mass assignment](./mass-assignment.md). |
| `guarded` | `List<String> get guarded` | Fields `fill` always rejects. |
| `strictMassAssignment` | `bool get strictMassAssignment` | Throw instead of skipping on guarded fields. Default `false`. |
| `hiddenFromSerialization` | `Set<String> get hiddenFromSerialization` | Names dropped from `toMap` / `toJson`. See [serialization](./serialization.md). |
| `computedAttributes` | `Map<String, Object?> get computedAttributes` | Extra serialized attributes. |
| `castManager` | `CastManager get castManager` | Casts applied on write and hydrate. See [casts](./casts.md). |
| `ormCascadeSpecs` | `List<OrmCascadeSpec> get ormCascadeSpecs` | ORM-side cascade delete specs. See [working with relations](../relations/working-with-relations.md). |
| `rules` | `Map<Field<Object?>, List<ValidationRule>> get rules` | Validation run on save. See [validation](./validation.md). |
| `updateRules` | `Map<Field<Object?>, List<ValidationRule>> get updateRules` | Update-path rules. Defaults to `rules`. |
| `exists` | `bool get exists` | Whether the row has been persisted. |
| `isDirty` | `bool isDirty([String? field])` | Any (or one) attribute changed since the last sync. |
| `dirtyFields` | `Set<String> get dirtyFields` | Unmodifiable set of dirty keys. |
| `setAttribute` | `void setAttribute(String name, Object? value)` | Write a value and mark it dirty. |
| `getAttribute` | `Object? getAttribute(String name)` | Read the live value. |
| `getOriginal` | `Object? getOriginal(String name)` | Pre-modification value, or `null`. |
| `getOriginalValue` | `T? getOriginalValue<T>(Field<T> field)` | Typed original value. |
| `hydrateAttribute` | `void hydrateAttribute(String name, Object? value)` | Seed a value without dirtying. |
| `markPersisted` | `void markPersisted()` | Snapshot originals and set `exists` to `true`. |
| `fill` | `void fill(Map<String, Object?> data)` | Mass-assign honoring `fillable` / `guarded`. Throws `MassAssignmentException` in strict mode. |
| `withoutTimestamps` | `Future<T> withoutTimestamps<T>(Future<T> Function() callback)` | Suspend timestamp maintenance for a callback. |
| `afterCommit` | `void afterCommit(void Function() callback)` | Queue a callback for after the surrounding commit. |
| `getRelation` | `T? getRelation<T>(String name)` | Read an eager-loaded relation. Throws `RelationNotLoadedException` (or `LazyLoadingException` under strict mode) when unloaded. See [eager loading](../relations/eager-loading.md). |
| `getInjected` | `T getInjected<T>(String name)` | Read a `withCount` / `withSum` / `withExists` aggregate. Throws `UninitializedFieldException` on miss. |
| `toMap` | `Map<String, Object?> toMap({Set<String>? only, Set<String>? hidden, bool includeRelations = false, int maxDepth = 2})` | Serialize to a JSON-shaped map. |
| `toJson` | `String toJson()` | JSON string via `toMap`. |
| `describe` | `SerializationDescriptor describe()` | The supported serialization customization point. Do not override `toMap`. |
| `serializationId` | `String get serializationId` | Stable id for cycle detection. Defaults to `'$id'`. |
| `serializationType` | `String get serializationType` | Stable type tag. Defaults to the runtime type name. |
| `save` | `Future<bool> save({TransactionContext? transaction})` | Insert or update. See [saving and updating](./saving-and-updating.md). |
| `delete` | `Future<bool> delete({TransactionContext? transaction})` | Delete the row. |
| `forceDelete` | `Future<bool> forceDelete({TransactionContext? transaction})` | Hard delete. Same as `delete` on plain models; real DELETE under [soft deletes](./soft-deletes.md). |
| `update` | `Future<bool> update(Map<String, Object?> data, {TransactionContext? transaction})` | `fill` then `save`. |
| `refresh` | `Future<void> refresh()` | Re-read from the database. Throws `ModelNotFoundException` when the row is gone. |
| `replicate` | `Model replicate({List<String> except = const []})` | Unsaved copy without key and timestamps. Base throws `UnsupportedOperationException`. |
| `replicatedAttributes` | `Map<String, Object?> replicatedAttributes({List<String> except = const []})` | Protected helper for `replicate` overrides. |

Lifecycle hook overrides (`beforeSave`, `afterCreate`, and the rest) are listed on [lifecycle hooks and observers](./lifecycle-hooks-and-observers.md).

### ModelRegistration

| Symbol | Signature | Description |
|---|---|---|
| `ModelRegistration` | `const ModelRegistration({required Type type, required String tableName, String primaryKeyColumn = 'id', PrimaryKeyType primaryKeyType = PrimaryKeyType.uuid, String connection = 'default', String? morphName})` | Per-model runtime metadata for `Worm.initialize`. |
| `effectiveMorphName` | `String get effectiveMorphName` | `morphName`, falling back to `tableName`. |

### ModelLookup

| Symbol | Signature | Description |
|---|---|---|
| `ModelLookup.tableNameOf` | `static String tableNameOf(Model model)` | Resolves override first, then registry. Throws `ConfigurationException('model.tableName.missing')`. |

## Continue reading

- [Code generation](./code-generation.md): what `worm gen` emits and how to run it.
- [Saving and updating](./saving-and-updating.md): the write path, dirty tracking, and refresh.
- [Validation](./validation.md): rules that run automatically on save.
- [Defining relations](../relations/defining-relations.md): wiring models together.
