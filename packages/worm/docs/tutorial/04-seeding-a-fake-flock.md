---
title: 'Part 4: Seeding a fake flock'
description: Build a Bird factory and a seeder for reproducible sample data.
---

Hand-typing test data gets old fast. This part builds a factory that mints birds and a seeder that fills the journal with a small, repeatable flock and their sightings.

## Goal

A `BirdsSeeder` that produces the same three birds and six sightings every time you run it, so the query examples in the next part have predictable data.

## A Bird factory

A factory knows how to build one sample instance. Worm bundles a faker for fake values. Give every bird a random nickname and a default species; the seeder varies the species in a moment.

```dart title="lib/factories/bird_factory.dart"
import 'package:worm/worm.dart';

import '../models/bird.dart';

/// Builds sample [Bird]s for seeders and tests.
///
/// `definition()` gives every bird a random nickname from the
/// bundled faker and a default species. Seeders override the
/// species with a `sequence` so the flock is varied but stable.
final class BirdFactory extends Factory<Bird> {
  /// Default constructor.
  const BirdFactory();

  @override
  Bird definition() => Bird(name: faker.firstName(), species: 'Robin');
}
```

`definition()` is the only method a factory must provide. `faker` is worm's shared fake-data source, available on every factory.

## A seeder

Scaffold a seeder:

```bash
dart run worm:worm make:seeder BirdsSeeder --table birds
```

Replace its body. The seeder does three things: fix the faker's random stream so nicknames repeat, build three birds while cycling their species, and record a few sightings for each.

```dart title="seeds/birds_seeder.dart"
import 'package:nestwatch/factories/bird_factory.dart';
import 'package:nestwatch/models/bird.dart';
import 'package:nestwatch/models/sighting.dart';
import 'package:worm/worm.dart';

/// Fills the journal with a small, reproducible flock and a few
/// sightings so the query examples have something to chew on.
final class BirdsSeeder extends Seeder {
  /// Default constructor.
  const BirdsSeeder();

  @override
  String get name => 'BirdsSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    // Deterministic faker stream: same nicknames every run.
    Worm.seedRandom(42);

    final flock = await const BirdFactory().count(3).sequence(
      <Map<String, Object?>>[
        <String, Object?>{'species': 'Robin'},
        <String, Object?>{'species': 'Jay'},
        <String, Object?>{'species': 'Wren'},
      ],
    ).create();

    final start = DateTime.utc(2026, 6);
    for (final (int index, Bird bird) in flock.indexed) {
      // Each bird gets index+1 sightings on consecutive June days.
      for (var day = 0; day <= index; day++) {
        await Sighting(
          birdId: bird.id.toString(),
          location: 'Feeder ${day + 1}',
          observedAt: start.add(Duration(days: index * 3 + day)),
          count: index + day + 1,
        ).save();
      }
    }
  }
}
```

Three factory pieces are doing the work:

- `Worm.seedRandom(42)` seeds the faker so `firstName()` returns the same nicknames on every run.
- `count(3)` plans three birds.
- `sequence([...])` cycles those maps one per bird, overriding the species. Bird one becomes a Robin, bird two a Jay, bird three a Wren.
- `create()` persists the whole plan and returns the saved birds.

The nested loop then logs one sighting for the first bird, two for the second, and three for the third: six sightings across fixed June dates. You defer the richer factory tools (`has`, `for_`, named states) to the [factories](../models/factories.md) page.

## Register the seeder

Add it to `bin/nestwatch.dart`. Import it, then put it in the seeders list:

```dart title="bin/nestwatch.dart"
    seeders: const <Seeder>[BirdsSeeder()],
```

## Run it on a clean journal

Parts 2 and 3 left a bird and a sighting behind. For a predictable flock, start the database fresh. The CLI does not track which seeders have run, so deleting the file is the simplest reset:

```bash
rm nestwatch.db
dart run nestwatch migrate
dart run nestwatch db:seed
```

## Checkpoint

The seed step reports the seeder that ran:

```text
seeded  BirdsSeeder
```

Your journal now holds three birds (a Robin, a Jay, and a Wren) and six sightings. Because the faker was seeded and the dates are fixed, that data is identical on every machine, which is exactly what the next part needs.

## What just happened

The factory turned one `definition()` into a batch of saved birds, with `sequence` steering each one. Because seeders build data through your models, every bird and sighting went through the same `save()` path as real writes, timestamps and all. `Worm.seedRandom` made the fake data reproducible, so your tests and docs can assert against exact values.

:::note
`db:seed` here runs through your own CLI, so it writes to `nestwatch.db`. Running the generic `dart run worm:worm db:seed` would seed an in-memory database and leave your file untouched.
:::

## Gotchas

- **The CLI does not track seeder runs.** Run `db:seed` twice and you get two flocks. That is why the reset above deletes the file. For idempotent seeding you wire a record store yourself; see [Seeding](../database/seeding.md).
- **Seeders declare an environment.** `BirdsSeeder` runs everywhere because a seeder defaults to every environment. Override the `environment` getter to keep heavy fixtures out of production.
- **`sequence` cycles, `count` sizes.** `count(3)` decides how many birds you get; `sequence([...])` cycles its maps across them. Give `sequence` fewer maps than `count` and it repeats from the top.
- **Seeding goes through `save()`.** Because the factory persists with real saves, validation rules and timestamps apply to seeded rows exactly as they do to hand-typed ones.

## Continue reading

- [Part 5: Queries that sing](./05-queries-that-sing.md)
- [Seeding](../database/seeding.md)
- [Factories](../models/factories.md)
