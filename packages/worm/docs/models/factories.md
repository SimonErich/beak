---
title: Factories
description: Build and persist realistic model instances for tests and seeders with states, sequences, and relation graphs.
---

Factories produce typed model instances on demand: one for a unit test, fifty for a seeder, a parent with three children for a relation test. This page covers the full factory surface. It builds on [defining models](./defining-models.md).

## Defining a factory

Extend `Factory<T>` and override `definition()`, which returns one fresh blueprint per call. The `faker` getter gives you deterministic fake data:

```dart title="user_factory.dart"
final _ids = Sequence();

final class UserFactory extends Factory<User> {
  @override
  User definition() =>
      User(id: _ids.next(), name: faker.firstName());

  @override
  Map<String, FactoryState<User>> get stateVariations => {
    'admin': (user) => user..setAttribute('role', 'admin'),
  };
}
```

`Sequence` is a small monotonic counter (`next()`, `reset()`, `peek`) that keeps generated ids unique across calls.

## Building vs creating

`make()` and `makeMany(n)` build instances in memory. `create()` builds, applies overrides, and persists:

```dart
final draft = UserFactory().make();          // built, not saved
final drafts = UserFactory().makeMany(3);    // three unsaved instances

final user = await UserFactory().create();   // built, saved, returned
final alice = await UserFactory().create(
  overrides: {'name': 'Alice'},              // overrides win over definition()
);
```

`create()` persists through `Model.save()`, so [validation](./validation.md) and [lifecycle hooks](./lifecycle-hooks-and-observers.md) run exactly as they do for any other save. It requires `Worm.initialize` to have run; otherwise the save throws `ConfigurationException`.

Overrides are applied with `fill()`, so [mass assignment](./mass-assignment.md) rules apply: guarded or non-fillable keys are silently skipped, or throw `MassAssignmentException` in strict mode.

## States

Declare named variations in `stateVariations` and select them with `state(name)`:

```dart
final admin = UserFactory().state('admin').make();
final admins = await UserFactory().state('admin').count(3).create();
```

`state()` returns a derived factory, so state calls compose and the original factory stays untouched. An unknown name throws `FactoryException`. For an inline, unnamed variation, use `withTransform`:

```dart
final banned = UserFactory()
    .withTransform((user) => user..setAttribute('banned', true))
    .make();
```

## Batches and sequences

`count(n)` plans a batch. `sequence(patterns)` cycles override patterns across the batch, one pattern per instance, wrapping around modulo the pattern count:

```dart
final five = await UserFactory().count(5).create();

final users = await UserFactory()
    .sequence([
      {'name': 'a'},
      {'name': 'b'},
    ])
    .count(4)
    .create();
// names: a, b, a, b
```

`count`, `sequence`, `has`, and `for_` all return an internal plan object. The plan chains the same four methods and finishes with `create({overrides})`, which returns `Future<List<T>>`. The plan type itself is deliberately private; you only interact with it through this fluent chain. Nothing touches the database until `create()`.

## Relation graphs

`has()` and `for_()` wire foreign keys through a typed `RelationField`, the same generated companions (like `User$.posts`) that eager loading uses:

```dart
// One user, plus three posts whose user_id points at it:
final users = await UserFactory()
    .has(PostFactory().count(3), User$.posts)
    .create();

// Three posts for an existing parent, user_id pre-filled:
final posts = await PostFactory()
    .for_(author, User$.posts)
    .count(3)
    .create();
```

- `has(childFactory, relation)` persists the parent first, then runs the child factory once per parent with the parent's primary key bound to `relation.foreignKey`. The child argument can be a plain factory or a planned chain like `PostFactory().count(3)`. Multiple `has()` calls compose.
- `for_(parent, relation)` pre-fills `relation.foreignKey` with `parent.id` on every produced instance. The last `for_()` call wins.

Without code generation, declare the field by hand:

```dart
const posts = RelationField<User, Post>('posts', foreignKey: 'user_id');
```

### Override precedence

When a plan merges values for one instance, later sources win:

1. `for_` foreign-key binding (weakest)
2. the cycled `sequence` pattern
3. explicit `create(overrides: ...)` (strongest)

## Deterministic fake data

`FakerService` is a singleton wrapper around `faker_dart`:

```dart
Worm.seedRandom(42); // forwards to FakerService.instance.seed(42)

final faker = FakerService.instance;
faker.name();        // 'Alice Carter'
faker.firstName();   // 'Alice'
faker.lastName();    // 'Carter'
faker.email();       // 'alice.carter@example.org'
faker.phoneNumber(); // '(415) 555-0134' style
```

Once seeded, these helpers draw from small bundled datasets with an internal seeded `Random`, so the same seed produces the same sequence across runs and across upgrades of the upstream package. That makes seeded output stable enough for snapshot tests.

For the full `faker_dart` surface, use `faker.raw`; values from `raw` are not covered by the determinism guarantee. `setLocale(...)` forwards to `faker_dart` and only affects non-seeded delegations.

## Where factories fit

- **Tests:** pair factories with a fresh `InMemoryAdapter` and `Worm.seedRandom` for reproducible fixtures. See [testing](../guides/testing.md).
- **Seeders:** seeders call the same factories to fill development databases. See [seeding](../database/seeding.md).

## Gotchas

- `create()` needs a running worm: call `Worm.initialize` first or the underlying `save()` throws `ConfigurationException`.
- `make()` never applies overrides or persists; overrides exist only on `create()`.
- Overrides pass through `fill()`, so mass-assignment protection applies to them.
- `sequence` patterns cycle modulo the pattern count; four instances over two patterns yields `a, b, a, b`.
- Multiple `has()` calls compose into independent child batches; multiple `for_()` calls don't compose, the last one wins.
- Override precedence is `for_` binding, then sequence pattern, then explicit `overrides`, later wins.
- `state('nope')` throws `FactoryException` naming the missing state.
- Derived factories from `state()` / `withTransform()` share the parent's `stateVariations`, so you can chain further `state()` calls on them.
- `Factory.create()` returns `Future<T>`, but after `count`/`sequence`/`has`/`for_` the plan's `create()` returns `Future<List<T>>`, even for a single instance.
- `has()` children are created once per parent instance in the plan.

## API summary

### Factory

| Symbol | Signature sketch | Description |
| --- | --- | --- |
| `Factory<T extends Model>` | `abstract base class; const Factory()` | Base class every model factory extends. |
| `Factory.definition` | `T definition()` | Returns one fresh blueprint per call; the only required override. |
| `Factory.stateVariations` | `Map<String, FactoryState<T>> get stateVariations` | Named transforms; defaults to empty. |
| `Factory.make` | `T make()` | Build one instance in memory. |
| `Factory.makeMany` | `List<T> makeMany(int count)` | Build N instances in memory. |
| `Factory.create` | `Future<T> create({Map<String, Object?> overrides = const {}})` | Build, `fill(overrides)`, and `save()` one instance. |
| `Factory.count` | `count(int n)` | Plan N instances; finish with `create()`. |
| `Factory.sequence` | `sequence(List<Map<String, Object?>> patterns)` | Plan cycling per-instance overrides. |
| `Factory.has` | `has<R extends Model>(childFactory, RelationField<T, R> relation)` | Plan child creation per persisted parent, foreign key bound. |
| `Factory.for_` | `for_<P extends Model>(P parent, RelationField<P, T> relation)` | Plan instances with the parent's key pre-filled. |
| `Factory.state` | `Factory<T> state(String name)` | Derived factory applying a named variation; throws `FactoryException` on unknown names. |
| `Factory.withTransform` | `Factory<T> withTransform(FactoryState<T> transform)` | Derived factory applying an inline transform. |
| `Factory.faker` | `FakerService get faker` | Shared `FakerService` singleton. |
| `FactoryState<T>` | `typedef FactoryState<T> = T Function(T base)` | A state variation: derives a new instance from a base one. |
| plan `create` | `Future<List<T>> create({Map<String, Object?> overrides = const {}})` | Terminal on any `count`/`sequence`/`has`/`for_` chain; persists all planned instances in order. |
| `FactoryException` | `const FactoryException({required String factoryState, required String message})` | Thrown on factory misuse, most commonly an unknown state name. |

### Fake data and sequences

| Symbol | Signature sketch | Description |
| --- | --- | --- |
| `FakerService.instance` | `static final FakerService instance` | The singleton. |
| `FakerService.seed` | `void seed(int value)` | Re-seed the deterministic generator; same seed, same sequence. |
| `FakerService.setLocale` | `void setLocale(FakerLocaleType locale)` | Forwards to `faker_dart`; affects non-seeded calls only. |
| `FakerService.name` / `firstName` / `lastName` | `String name()` etc. | Deterministic personal names from bundled datasets. |
| `FakerService.email` | `String email()` | `firstname.lastname@domain` from bundled datasets. |
| `FakerService.phoneNumber` | `String phoneNumber()` | North American style phone number. |
| `FakerService.raw` | `Faker get raw` | The wrapped `faker_dart` instance; no determinism guarantee. |
| `Worm.seedRandom` | `static void seedRandom(int seed)` | Forwards to `FakerService.instance.seed`. |
| `Sequence` | `Sequence({int start = 1})` | Monotonic integer counter. |
| `Sequence.next` | `int next()` | Return the current value and advance. |
| `Sequence.reset` | `void reset()` | Return to the starting value. |
| `Sequence.peek` | `int get peek` | Value the next `next()` will return. |
| `Sequence.start` | `int get start` | The configured starting value. |
| `FactorySequence` | `typedef FactorySequence = Sequence` | Alias for `Sequence`. |

## Continue reading

- [Seeding](../database/seeding.md): run factories inside seeders to fill a development database.
- [Testing](../guides/testing.md): the full test setup with `InMemoryAdapter`, `Worm.reset`, and seeded fakers.
- [Defining relations](../relations/defining-relations.md): where `RelationField` companions come from.
