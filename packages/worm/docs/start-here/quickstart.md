---
title: Quickstart
description: From an empty project to a passing typed query in one Dart file, no database required.
---

One file, one run: define a model, save three rows, and filter them with a typed query on the in-memory adapter. No database server, no build step.

## 1. Create a project

```sh
dart create quickstart
cd quickstart
dart pub add 'worm:{"path":"/path/to/beak/packages/worm"}'
```

Point the path at the `packages/worm` folder of your beak checkout (worm is not on pub.dev yet; see [installation](./installation.md)).

## 2. Write the file

Replace `bin/quickstart.dart` with this:

```dart title="bin/quickstart.dart"
import 'package:worm/worm.dart';

/// A user of your app. One class, one table.
final class User extends Model {
  User({required this.id, required this.name, required this.age});

  /// Builds a User from a raw database row. No `as` casts:
  /// a wrong shape throws a FormatException instead.
  factory User.fromRow(Map<String, Object?> row) => switch (row) {
    {'id': final String id, 'name': final String name, 'age': final int age} =>
      User(id: id, name: name, age: age),
    _ => throw FormatException('Unexpected row shape for User: $row'),
  };

  final String id;
  final String name;
  final int age;

  @override
  String get tableName => 'users';

  @override
  Map<String, Object?> toRow() => {'id': id, 'name': name, 'age': age};

  /// Typed query entry point.
  static QueryBuilder<User> query() => QueryBuilder<User>.from(
    QueryContext<User>(
      adapter: Worm.adapter(),
      table: 'users',
      hydrate: User.fromRow,
    ),
  );
}

/// Typed field companion. This is the shape worm's code
/// generator emits; a few lines to write by hand.
abstract final class User$ {
  static const StringField name = StringField('name');
  static const ComparableField<int> age = ComparableField<int>('age');
}

Future<void> main() async {
  await Worm.initialize(
    config: const WormConfig(),
    adapters: {'default': InMemoryAdapter()},
    models: const [ModelRegistration(type: User, tableName: 'users')],
  );

  await Worm.adapter().executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );

  await User(id: 'u1', name: 'Ada', age: 36).save();
  await User(id: 'u2', name: 'Grace', age: 45).save();
  await User(id: 'u3', name: 'Kai', age: 12).save();

  final adults = await User.query()
      .where(User$.age.gte(18))
      .orderBy(User$.name)
      .get();

  for (final user in adults) {
    print('${user.name} (${user.age})');
  }

  await Worm.reset();
}
```

## 3. Run it

```sh
dart run bin/quickstart.dart
```

```txt
Ada (36)
Grace (45)
```

Kai is 12, and `User$.age.gte(18)` filtered him out. Note the types: `gte` only exists on comparable fields, and `User$.age.gte('18')` would not compile.

## What just happened

- **The model.** `User` extends `Model`, which brings `save()`, `delete()`, and friends. `toRow()` says how it becomes a row; `fromRow` says how a row becomes a `User`. Details in [defining models](../models/defining-models.md).
- **The companion.** `User$` holds typed field constants. This file writes it by hand; [code generation](../models/code-generation.md) covers generating it from annotations instead.
- **`Worm.initialize`.** Registers adapters by connection name and connects them. `InMemoryAdapter` is a real adapter that happens to live in RAM, which is why tests love it. More in [configuration](./configuration.md).
- **The typed query.** `where` takes a predicate built from field constants, and `get()` runs the query and hydrates models.

## What this skipped

Real projects add [migrations](../database/migrations.md) instead of a raw `createTable`, [relations](../relations/defining-relations.md) between models, and [validation](../models/validation.md) before writes. Each is one page away.

## Where next

- **Build something real:** the [tutorial](../tutorial/overview.md) grows a bird-sighting journal on SQLite, one concept at a time.
- **Go straight to concepts:** [defining models](../models/defining-models.md) is the hub for everything a model can do.

## Continue reading

- [Tutorial overview](../tutorial/overview.md) The guided build.
- [Defining models](../models/defining-models.md) The model concept hub.
- [Configuration](./configuration.md) What `Worm.initialize` actually does.
