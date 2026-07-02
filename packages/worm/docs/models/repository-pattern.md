---
title: Repository pattern
description: Opt into a data-mapper style with Repository<T> when you would rather keep persistence off the model.
---

Worm's default style is Active Record: you call `save()`, `delete()`, and `query()` on the model itself. If you prefer to keep persistence logic in a separate class, subclass `Repository<T>` instead. Both styles sit on the same engine. Pick one style per project.

## Active Record vs. data mapper

Active Record puts CRUD on the model. A repository moves that CRUD into a dedicated class and hands it the data through method calls.

| Concern | Active Record | Repository |
| --- | --- | --- |
| Where CRUD lives | On the model (`user.save()`) | On the repository (`repo.save(user)`) |
| Adapter | Resolved from the `Worm` registry | Injected into the repository |
| Lookups | `User.query()` | `repo.find`, `repo.all` |
| Entry point | The model class | A repository instance you construct |

Neither is faster than the other. The repository is a boundary you build on purpose, so it suits projects that want persistence out of the domain model.

## Defining a repository

Subclass `Repository<T>`. You provide two things: the `tableName` and a `hydrate` callback that turns a row into a typed model. The adapter is a constructor argument, so you inject it explicitly.

```dart title="user_repository.dart"
import 'package:worm/worm.dart';

import 'user.dart';

final class UserRepository extends Repository<User> {
  const UserRepository(super.adapter);

  @override
  String get tableName => 'users';

  @override
  User hydrate(Map<String, Object?> row) => User.fromRow(row);
}
```

`hydrate` reuses the same `User.fromRow` factory your model already defines (see [defining models](./defining-models.md)). If your primary key column isn't `id`, override `primaryKeyColumn` too.

## Using a repository

Construct the repository with an adapter, then call its CRUD methods. Pass the adapter from the `Worm` registry so reads and writes agree on one connection.

```dart
final users = UserRepository(Worm.adapter());

final ada = User(name: 'Ada', age: 36);
await users.save(ada);                  // insert or update

final found = await users.find('u-Ada');       // User?, null when missing
final loaded = await users.findOrFail('u-Ada'); // User, throws when missing
final everyone = await users.all();             // List<User>
final removed = await users.deleteById('u-Ada'); // int rows deleted
```

`find` returns `null` when no row matches. `findOrFail` throws `ModelNotFoundException` instead, which is the right call when a missing row is a bug rather than an expected state. `all` loads every row in the table, and `deleteById` deletes by primary key and returns the affected count. There's no query builder on the repository itself; for filtered reads, keep using `User.query()` or add your own methods that wrap it.

## Same engine underneath

`save`, `delete`, and `refresh` forward straight to the Active Record orchestrator. So a repository `save` still runs validation rules, fires lifecycle hooks and observers, and stamps timestamps, exactly as `user.save()` would. Those three writes resolve their adapter from the model's connection in the `Worm` registry, not from the one you injected. The read methods (`find`, `findOrFail`, `all`, `deleteById`) run against the injected adapter directly.

## Gotchas

- **`Worm.initialize` is still required.** `save`, `delete`, and `refresh` go through Active Record, which reads the adapter from the registry. Initialize worm before you use them.
- **Inject the registry adapter.** Pass `Worm.adapter()` (or `Worm.adapter('connection')`) so the read methods and the write methods target the same database.
- **No query builder on the repository.** `find` and `all` cover key lookups and full-table reads. For anything with a `where` clause, use `User.query()` or wrap it in a repository method of your own.
- **`hydrate` should build, not persist.** The repository calls `markPersisted()` on the hydrated model for you after `find` and `all`.

## API summary

| Member | Signature | Notes |
| --- | --- | --- |
| Constructor | `const Repository(DatabaseAdapter adapter)` | Inject the adapter used by the read methods. |
| `tableName` | `String get tableName` | Abstract. The table this repository targets. |
| `hydrate` | `T hydrate(Map<String, Object?> row)` | Abstract. Build a typed model from a row. |
| `primaryKeyColumn` | `String get primaryKeyColumn` | Defaults to `'id'`. |
| `save` | `Future<bool> save(T model)` | Insert or update. `false` when a `before` hook cancels. |
| `delete` | `Future<bool> delete(T model)` | Delete the model through Active Record. |
| `refresh` | `Future<void> refresh(T model)` | Re-read the model from the database. |
| `find` | `Future<T?> find(Object id)` | Look up by primary key, or `null`. |
| `findOrFail` | `Future<T> findOrFail(Object id)` | Look up by primary key, or throw `ModelNotFoundException`. |
| `all` | `Future<List<T>> all()` | Load every row as `List<T>`. |
| `deleteById` | `Future<int> deleteById(Object id)` | Delete by primary key. Returns the affected count. |

## Continue reading

- [Defining models](./defining-models.md): the model, `fromRow`, and `tableName` your repository hydrates and targets.
- [Testing](../guides/testing.md): a repository is an easy seam to inject a fake adapter in tests.
