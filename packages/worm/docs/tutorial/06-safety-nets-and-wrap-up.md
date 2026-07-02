---
title: 'Part 6: Safety nets and wrap-up'
description: Add validation, an observer, a transaction, and query logging, then find your way into the rest of the docs.
---

Your journal works. This part makes it trustworthy: validation rejects bad data, an observer reacts to new sightings, a transaction keeps a multi-step write atomic, and a logging wrapper shows every query. Then you get a map to the rest of the docs.

## Goal

A `Bird` that refuses invalid input, a `SightingObserver` that fires on new sightings, a transaction that writes two things as one, and a one-run peek at the SQL your app sends.

## Validation

Rules live on the model, keyed by the field they check. Add a `rules` getter to `Bird` in `lib/models/bird.dart`:

```dart title="lib/models/bird.dart"
  @override
  Map<Field<Object?>, List<ValidationRule>> get rules =>
      <Field<Object?>, List<ValidationRule>>{
        Bird$.name: <ValidationRule>[const Required(), const MinLength(2)],
        Bird$.species: <ValidationRule>[const Required()],
      };
```

Now `save()` runs these rules first. A bird needs a name of at least two characters and a species. A failing save throws `ValidationException` and never touches the database.

## An observer

An observer reacts to a model's lifecycle events. Write one that logs each new sighting:

```dart title="lib/observers/sighting_observer.dart"
import 'package:worm/worm.dart';

import '../models/sighting.dart';

/// Prints a line every time a new [Sighting] is recorded.
final class SightingObserver extends ModelObserver<Sighting> {
  /// Default constructor.
  const SightingObserver();

  @override
  Future<void> afterCreate(Sighting sighting) async {
    print(
      '  [observer] logged a sighting at ${sighting.location} '
      '(x${sighting.count})',
    );
  }
}
```

Observers register at startup. Extend `bootNestwatch` in `lib/nestwatch.dart` to accept them and pass them to `Worm.initialize`:

```dart title="lib/nestwatch.dart"
Future<DatabaseAdapter> bootNestwatch({
  String path = 'nestwatch.db',
  List<Observer<Object>> observers = const <Observer<Object>>[],
}) async {
  final adapter = SqliteAdapter.open(path);
  await adapter.connect();
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
    models: const <ModelRegistration>[],
    observers: observers,
  );
  return adapter;
}
```

## A transaction

`Worm.transaction` runs a block against a single connection and commits only if it finishes. Pass the transaction handle to each `save(transaction: txn)` so every write shares it.

```dart title="bin/safety_nets.dart"
import 'package:nestwatch/models/bird.dart';
import 'package:nestwatch/models/sighting.dart';
import 'package:nestwatch/nestwatch.dart';
import 'package:nestwatch/observers/sighting_observer.dart';
import 'package:worm/worm.dart';

Future<void> main() async {
  // Register the observer for this run.
  await bootNestwatch(observers: const <Observer<Object>>[SightingObserver()]);

  // 1. Validation stops a bad write before it hits the database.
  try {
    await Bird(name: 'A', species: 'Robin').save();
  } on ValidationException catch (e) {
    print('Rejected: ${e.errors.length} field(s) failed validation.');
  }

  // 2. A transaction keeps a multi-step write all-or-nothing.
  final before = await Sighting.query().count();
  await Worm.transaction((txn) async {
    final wren = await Bird.query()
        .where(Bird$.species.eq('Wren'))
        .firstOrFail();
    await Sighting(
      birdId: wren.id.toString(),
      location: 'Hedgerow',
      observedAt: DateTime.utc(2026, 6, 20, 6),
      count: 4,
    ).save(transaction: txn);
  });
  final after = await Sighting.query().count();
  print('Sightings before: $before, after: $after');
}
```

## Checkpoint

Run it on the freshly seeded journal from Part 4:

```bash
dart run bin/safety_nets.dart
```

```text
Rejected: 1 field(s) failed validation.
  [observer] logged a sighting at Hedgerow (x4)
Sightings before: 6, after: 7
```

The invalid bird was rejected: `name` is one character, so `MinLength(2)` failed, and `ValidationException.errors` reported the failing field. The transaction found the Wren and saved a new sighting, and the observer's `afterCreate` fired the moment that row was created. The count went from six to seven, all in one committed unit.

## See the queries

Worm can wrap any adapter to log every call. Point one run at a `LoggingAdapter`:

```dart title="bin/with_logging.dart"
import 'package:nestwatch/models/bird.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

Future<void> main() async {
  final sqlite = SqliteAdapter.open('nestwatch.db');
  await sqlite.connect();

  // Wrap the real adapter so every query prints a log line.
  final logged = LoggingAdapter(
    inner: sqlite,
    logger: ConsoleQueryLogger(),
    strictness: const StrictnessConfig(),
    adapterName: 'sqlite',
  );

  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': logged},
  );

  final wrens = await Bird.query().where(Bird$.species.eq('Wren')).get();
  print('Found ${wrens.length} wren(s).');
}
```

```bash
dart run bin/with_logging.dart
```

```text
[2026-07-02 14:11:37.039] [QUERY] SELECT * FROM "birds" WHERE "species" = ?
-- Params: [Wren] | params: [Wren] | 8.4ms
Found 1 wren(s).
```

The timestamp and duration will differ on your machine. `LoggingAdapter` wraps any `DatabaseAdapter`, so you can flip it on for a debugging run and remove it in production.

## A word on strict mode

Worm already refused to lazy-load a relation in Part 3: reading one you never loaded throws `RelationNotLoadedException`, and that guard is on by default. `StrictnessConfig` adds more guards on top. You can make full-table scans and destructive writes without a `WHERE` clause throw, so a careless query fails loudly in development instead of quietly in production. See [Strict mode](../guides/strict-mode.md) to turn those on.

## Where to next

Your bird is fed. Go build something. Every concept the tutorial touched has a page that goes deeper:

- Models: [Defining models](../models/defining-models.md), [Validation](../models/validation.md), [Lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md), [Factories](../models/factories.md), [Soft deletes](../models/soft-deletes.md).
- Queries: [Query basics](../queries/query-basics.md), [Advanced queries](../queries/advanced-queries.md), [Pagination](../queries/pagination.md), [Scopes](../queries/scopes.md).
- Relations: [Defining relations](../relations/defining-relations.md), [Eager loading](../relations/eager-loading.md).
- Database: [Migrations](../database/migrations.md), [Seeding](../database/seeding.md), [Transactions](../database/transactions.md).
- Drivers: [Choosing a database](../drivers/choosing-a-database.mdx) when you outgrow SQLite.
- Guides: [Testing](../guides/testing.md), [Logging and debugging](../guides/logging-and-debugging.md), [Strict mode](../guides/strict-mode.md), [Production](../guides/production.md).

## Continue reading

- [Defining models](../models/defining-models.md)
- [Transactions](../database/transactions.md)
- [Choosing a database](../drivers/choosing-a-database.mdx)
