---
title: Annotations
description: Complete catalog of worm's model annotations, their generator behavior, and the stable Model-override equivalents.
---

Every annotation in `package:worm/annotations.dart`, with its exact constructor, what the code generator does with it, and its stability status. This page builds on [code generation](../models/code-generation.md) and [defining models](../models/defining-models.md).

Annotations are generator input only. They carry no runtime behavior by themselves; `worm gen` reads them and emits code into the model's `.g.dart` part file. Hand-written models achieve the same results by overriding `Model` getters directly.

```dart
import 'package:worm/annotations.dart';
```

:::caution[GlobalScope name clash]
`package:worm/worm.dart` re-exports the annotations but hides the `GlobalScope` annotation, because the runtime scope class is also named `GlobalScope`. In a file that imports both libraries, the bare name `GlobalScope` is ambiguous. Prefix the annotations import (`import 'package:worm/annotations.dart' as ann;`) or add a `hide` clause to one side.
:::

## Mini-index

| Annotation | Status | One-liner |
| --- | --- | --- |
| [@Table](#table) | Stable | Maps a class to a database table |
| [@Column](#column) | Stable | Marks a field as a database column |
| [@PrimaryKey](#primarykey) | Stable | Declares the primary key column and strategy |
| [@HasOne](#hasone) | Stable | One-to-one relation |
| [@HasMany](#hasmany) | Stable | One-to-many relation |
| [@BelongsTo](#belongsto) | Stable | Inverse relation |
| [@BelongsToMany](#belongstomany) | Stable | Many-to-many via pivot table |
| [@HasOneThrough](#hasonethrough) | Stable | One-to-one through an intermediate model |
| [@HasManyThrough](#hasmanythrough) | Stable | One-to-many through an intermediate model |
| [@MorphOne](#morphone) | Stable | Polymorphic one-to-one |
| [@MorphMany](#morphmany) | Stable | Polymorphic one-to-many |
| [@MorphTo](#morphto) | Stable | Inverse polymorphic relation |
| [@MorphToMany](#morphtomany) | Stable | Polymorphic many-to-many |
| [@Scope](#scope) | Stable | Declares a local query scope name |
| [@GlobalScope](#globalscope) | Stable | Registers a global query scope class |
| [OnDelete](#ondelete) | Stable (enum) | Referential action for deletes |
| [@Hidden](#hidden) | Experimental | Hide a field from serialization |
| [@Appended](#appended) | Experimental | Append a computed attribute to output |
| [@Attribute](#attribute) | Experimental | Declare a virtual attribute accessor |
| [@CastAs](#castas) | Experimental | Assign a value cast to a field |
| [@Fillable](#fillable) | Experimental | Whitelist mass-assignable fields |
| [@Guarded](#guarded) | Experimental | Blacklist fields from mass assignment |
| [@Computed](#computed) | Experimental | Mark a method as a computed attribute |

## Core annotations

### @Table

**Signature**

```dart
const Table({String? name, String connection = 'default'})
```

**Example**

```dart
import 'package:worm/annotations.dart';

part 'user.g.dart';

@Table() // table name derived: 'users'
class User { /* ... */ }

@Table(name: 'members', connection: 'analytics')
class Member { /* ... */ }
```

The entry-point annotation: only `@Table`-annotated classes are processed by the generator. `name` defaults to the pluralized snake_case class name via `NamingConvention.tableName`.

**Gotchas**

- Applying `@Table` to anything that is not a class fails the build with `InvalidGenerationSourceError('@Table can only be applied to classes.')`.
- A non-default `connection` is emitted as a `connectionName` override inside the opt-in `_$<Name>Annotations` mixin. It only routes persistence if you mix that in (see [Experimental annotations](#experimental-annotations)).
- The generated `query()` starter currently resolves `Worm.adapter()` (the default connection) regardless of `connection`. Generated relation accessors do honor `connectionName`.

**Related:** [naming conventions](./naming-conventions.md), [code generation](../models/code-generation.md), [multiple connections](../database/multiple-connections.md)

### @Column

**Signature**

```dart
const Column({String? name, ColumnType? type, bool nullable = false, Object? defaultValue})
```

**Example**

```dart
@Column()
final String firstName;              // db column: 'first_name'

@Column(name: 'session_duration')
final int sessionDuration;           // explicit db name
```

Marks a field as a database column. Only `@Column`-annotated fields become companion `Field` constants and participate in `fromRow` / `toRow` hydration.

**Gotchas**

- `name` defaults to `NamingConvention.toSnakeCase(fieldName)`.
- Nullability of the generated column descriptor comes from the Dart type's `?` suffix, not from the `nullable:` parameter.
- The `type`, `nullable`, and `defaultValue` parameters are declared for schema tooling but are not consumed by the current generator. Column types in migrations come from the [schema builder](../database/schema-builder.md).
- A field without `@Column` is invisible to codegen, even if it has other annotations.

**Related:** [FieldKind inference](#fieldkind-inference), [defining models](../models/defining-models.md), [operators and fields](./operators-and-fields.md)

### @PrimaryKey

**Signature**

```dart
const PrimaryKey({String columnName = 'id', PrimaryKeyType type = PrimaryKeyType.uuid})
```

**Example**

```dart
@PrimaryKey()
@Column()
final String id;
```

Declares the primary key column and its generation strategy. `PrimaryKeyType` values: `uuid` (default), `integer`.

**Gotchas**

- The build_runner generator does not currently read this annotation. A field carrying only `@PrimaryKey()` (without `@Column`) is not emitted as a companion constant and is not hydrated. Add `@Column()` alongside it when the key should round-trip.
- At runtime, the primary key column and type come from the `Model.primaryKeyColumn` override (default `'id'`) and `ModelRegistration.primaryKeyType` (default `PrimaryKeyType.uuid`).

**Related:** [defining models](../models/defining-models.md), [migrations](../database/migrations.md)

## Relation annotations

All ten relation annotations are read by the generator into typed `RelationField` constants on the companion (for example `User$.posts`), except `@MorphTo`, which is skipped by design. Foreign keys default to `<snake_case_parent>_id`; local keys default to `'id'`.

### @HasOne

**Signature**

```dart
const HasOne(Type related, {String? foreignKey, String? localKey, OnDelete onDelete = OnDelete.restrict})
```

**Example**

```dart
@HasOne(Profile)
final Profile profile;
```

**Gotchas**

- Generates a `RelationField<Parent, Related>` constant and a `profile$` accessor getter returning a `HasOneAccessor`.
- The `onDelete` parameter is declarative in the current generator; it does not yet emit `ormCascadeSpecs`. For ORM-side cascade deletes, override `ormCascadeSpecs` on the model.

**Related:** [defining relations](../relations/defining-relations.md), [OnDelete](#ondelete)

### @HasMany

**Signature**

```dart
const HasMany(Type related, {String? foreignKey, String? localKey, OnDelete onDelete = OnDelete.restrict})
```

**Example**

```dart
@HasMany(Post)
final List<Post> posts;
```

**Gotchas**

- Generates a `RelationField` constant plus a `posts$` accessor getter returning a `HasManyAccessor`.
- Same `onDelete` caveat as [@HasOne](#hasone).

**Related:** [defining relations](../relations/defining-relations.md), [eager loading](../relations/eager-loading.md)

### @BelongsTo

**Signature**

```dart
const BelongsTo(Type related, {String? foreignKey, String? ownerKey})
```

**Example**

```dart
@BelongsTo(User)
final User author;
```

**Gotchas**

- Generates a `RelationField` constant (cardinality one) but no `$`-suffixed accessor getter; accessors are emitted for `@HasOne`, `@HasMany`, and `@BelongsToMany` only.

**Related:** [defining relations](../relations/defining-relations.md)

### @BelongsToMany

**Signature**

```dart
const BelongsToMany(Type related, {String? pivotTable, String? foreignPivotKey, String? relatedPivotKey, OnDelete onDelete = OnDelete.restrict})
```

**Example**

```dart
@BelongsToMany(Role)
final List<Role> roles;
```

**Gotchas**

- `pivotTable` defaults to both class names snake_cased and joined alphabetically: `User` and `Role` produce `role_user`.
- Pivot keys default to `<snake_case_class>_id` on each side (`user_id`, `role_id`).
- Generates a `roles$` accessor getter returning a `BelongsToManyAccessor`.

**Related:** [defining relations](../relations/defining-relations.md), [naming conventions](./naming-conventions.md)

### @HasOneThrough

**Signature**

```dart
const HasOneThrough(Type related, {required Type through, String? firstKey, String? secondKey})
```

**Example**

```dart
@HasOneThrough(Supplier, through: Account)
final Supplier supplier;
```

**Gotchas**

- Read as cardinality one; emits a `RelationField` constant, no accessor getter.
- `firstKey` targets the intermediate table, `secondKey` the final table.

**Related:** [defining relations](../relations/defining-relations.md)

### @HasManyThrough

**Signature**

```dart
const HasManyThrough(Type related, {required Type through, String? firstKey, String? secondKey})
```

**Example**

```dart
@HasManyThrough(Comment, through: Post)
final List<Comment> comments;
```

**Gotchas**

- Read as cardinality many; emits a `RelationField` constant, no accessor getter.

**Related:** [defining relations](../relations/defining-relations.md)

### @MorphOne

**Signature**

```dart
const MorphOne(Type related, {String? morphName})
```

**Example**

```dart
@MorphOne(Image)
final Image image;
```

**Gotchas**

- `morphName` drives the `<name>_type` / `<name>_id` column pair on the related table.
- Emits a `RelationField` constant (cardinality one).

**Related:** [polymorphic relations](../relations/polymorphic-relations.md)

### @MorphMany

**Signature**

```dart
const MorphMany(Type related, {String? morphName})
```

**Example**

```dart
@MorphMany(Comment)
final List<Comment> comments;
```

**Gotchas**

- Emits a `RelationField` constant (cardinality many).

**Related:** [polymorphic relations](../relations/polymorphic-relations.md)

### @MorphTo

**Signature**

```dart
const MorphTo({Map<String, Type> types = const {}})
```

**Example**

```dart
@MorphTo(types: {'post': Post, 'video': Video})
final Object commentable;
```

The inverse side of a polymorphic relation: the child points at one of several parent types.

**Gotchas**

- The generator intentionally skips `@MorphTo` fields: the child type is dynamic at runtime, so no typed `RelationField` constant is emitted. Use the runtime `MorphTo` machinery and the `MorphRegistry` instead.

**Related:** [polymorphic relations](../relations/polymorphic-relations.md), [Worm runtime: morphRegistry](./worm-runtime.md#morphregistry)

### @MorphToMany

**Signature**

```dart
const MorphToMany(Type related, {String? morphName, String? pivotTable})
```

**Example**

```dart
@MorphToMany(Tag)
final List<Tag> tags;
```

**Gotchas**

- Emits a `RelationField` constant (cardinality many).

**Related:** [polymorphic relations](../relations/polymorphic-relations.md)

## Scope annotations

### @Scope

**Signature**

```dart
const Scope(String name)
```

**Example**

```dart
@Table()
class Post {
  @Scope('published')
  static void published() {}
}
```

Declares a local query scope on a model method.

**Gotchas**

- The current build path emits only name metadata: a `static const List<String> scopeNames` constant on the companion extension. It does not generate a typed `QueryBuilder` extension method, and there is no runtime `applyScope(String)` API.
- For working, reusable scopes today, define a `LocalScope<T>` class (or `CallableLocalScope`) and apply it with `QueryBuilder.scope(...)`. See [scopes](../queries/scopes.md).

**Related:** [scopes](../queries/scopes.md), [code generation](../models/code-generation.md)

### @GlobalScope

**Signature**

```dart
const GlobalScope(Type scopeType)
```

**Example**

```dart
import 'package:worm/annotations.dart' as ann;
import 'package:worm/worm.dart';

@Table()
@ann.GlobalScope(TenantScope)
class Order { /* ... */ }
```

Registers a global scope class on the model. The generator emits a `const` instance of `scopeType` into the companion's `globalScopes` list, which the generated `query()` starter wires into every `QueryBuilder<Model>`.

**Gotchas**

- `scopeType` must be a class with a `const` zero-argument constructor that extends the runtime `GlobalScope<Model>` class; the generator emits `ScopeType()` in a `const` list.
- The annotation and the runtime scope class share the name `GlobalScope`; see the name-clash caution at the top of this page.
- Bypass at query time with `withoutGlobalScope<ScopeType>()` or `withoutGlobalScopes()`.

**Related:** [scopes](../queries/scopes.md), [code generation](../models/code-generation.md)

## Supporting types

### OnDelete

**Signature**

```dart
enum OnDelete { cascade, ormCascade, restrict, setNull, setDefault, noAction }
```

Exported from `package:worm/annotations.dart` and used by the `onDelete` parameters of `@HasOne`, `@HasMany`, and `@BelongsToMany`.

| Value | Behavior |
| --- | --- |
| `cascade` | Database engine deletes dependent rows silently; no model hooks fire. |
| `ormCascade` | The ORM deletes dependent rows before the parent, firing `beforeDelete` / `afterDelete` on each child. The database foreign key stays `NO ACTION`. |
| `restrict` | Deletion is prevented while dependents exist. Default. |
| `setNull` | Foreign key column is set to `NULL`. |
| `setDefault` | Foreign key column is set to its default. |
| `noAction` | Database default; nothing happens. |

**Gotchas**

- `ormCascade` behavior at runtime is driven by the model's `ormCascadeSpecs` override, which `ActiveRecord.delete` walks child-first. The current generator does not emit that override from `onDelete`; write it by hand.

**Related:** [defining relations](../relations/defining-relations.md), [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md)

## FieldKind inference

The generator picks the typed field flavor for each `@Column` from the field's Dart type:

| Dart field type | FieldKind | Generated constant | Extra operators |
| --- | --- | --- | --- |
| `String` | `FieldKind.string` | `StringField` | LIKE family |
| `int`, `double`, `num`, `DateTime` | `FieldKind.comparable` | `ComparableField<T>` | Range comparisons |
| anything else | `FieldKind.plain` | `Field<T>` | Equality, null, list only |

Nullable types (`int?`) are stripped to their base type before inference.

**Related:** [operators and fields](./operators-and-fields.md)

## Experimental annotations

**Status: experimental. Do not rely on these seven annotations to change runtime behavior on their own.** The stable, canonical mechanism for each concern is a `Model` override:

| Annotation | Working equivalent (override on your model) |
| --- | --- |
| `@Hidden` | `Set<String> get hiddenFromSerialization` |
| `@Fillable` | `List<String> get fillable` |
| `@Guarded` | `List<String> get guarded` |
| `@CastAs` | `CastManager get castManager` |
| `@Appended`, `@Attribute`, `@Computed` | `Map<String, Object?> get computedAttributes` and `describe()` |

For `@Hidden`, `@CastAs`, `@Fillable`, and `@Guarded`, `worm gen` does emit the matching overrides, but only into an opt-in mixin named `_$<Model>Annotations`. Nothing happens unless you mix it in yourself:

```dart
class User extends Model with _$UserAnnotations {
  // annotation-driven overrides now active
}
```

`@Appended`, `@Attribute`, and `@Computed` are ignored by the current generator entirely.

### @Hidden

**Signature**

```dart
const Hidden()
```

**Example**

```dart
@Column()
@Hidden()
final String password;
```

**Gotchas**

- Effective only through the opt-in `_$<Model>Annotations` mixin, which adds the snake_case column name to `hiddenFromSerialization`.
- Stable alternative: override `Set<String> get hiddenFromSerialization => const {'password'};` directly.

**Related:** [serialization](../models/serialization.md)

### @Appended

**Signature**

```dart
const Appended(String name)
```

**Gotchas**

- Not read by the current generator. Override `computedAttributes` (and, for full control, `describe()`) instead.

**Related:** [serialization](../models/serialization.md)

### @Attribute

**Signature**

```dart
const Attribute(String name)
```

**Gotchas**

- Not read by the current generator. Model attribute access goes through `getAttribute` / `setAttribute`; virtual attributes belong in `computedAttributes`.

**Related:** [defining models](../models/defining-models.md), [serialization](../models/serialization.md)

### @CastAs

**Signature**

```dart
const CastAs(Type castType)
```

**Example**

```dart
@Column(name: 'session_duration')
@CastAs(DurationCast)
final int sessionDuration;
```

**Gotchas**

- Effective only through the opt-in `_$<Model>Annotations` mixin, which maps the column name to a cast instance in `castManager`.
- The generator emits `const DurationCast()`, so `castType` must have a `const` zero-argument constructor.
- Stable alternative: override `CastManager get castManager` directly.

**Related:** [casts](../models/casts.md)

### @Fillable

**Signature**

```dart
const Fillable(List<String> fields)
```

**Example**

```dart
@Table()
@Fillable(['first_name', 'last_name'])
class User { /* ... */ }
```

**Gotchas**

- Effective only through the opt-in `_$<Model>Annotations` mixin. The list is passed through verbatim; use database column names.
- Stable alternative: override `List<String> get fillable`. An empty `fillable` means "everything fillable" (minus `guarded`).

**Related:** [mass assignment](../models/mass-assignment.md), [security guide](../guides/security.md)

### @Guarded

**Signature**

```dart
const Guarded(List<String> fields)
```

**Example**

```dart
@Table()
@Guarded(['password'])
class User { /* ... */ }
```

**Gotchas**

- Effective only through the opt-in `_$<Model>Annotations` mixin.
- Stable alternative: override `List<String> get guarded`. Guarded wins over fillable: a key in both lists is rejected.

**Related:** [mass assignment](../models/mass-assignment.md)

### @Computed

**Signature**

```dart
const Computed(String name)
```

**Gotchas**

- Not read by the current generator. Override `Map<String, Object?> get computedAttributes` to expose computed values in serialization output.

**Related:** [serialization](../models/serialization.md)

## Continue reading

- [Code generation](../models/code-generation.md) for what `worm gen` emits from these annotations and how to run it.
- [Defining models](../models/defining-models.md) for the `Model` overrides that back every annotation.
- [Defining relations](../relations/defining-relations.md) for the relation annotations in practice, with defaults and query counts.
- [Naming conventions](./naming-conventions.md) for how table, column, foreign-key, and pivot names are derived.
