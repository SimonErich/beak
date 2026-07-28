---
title: Seeding
description: Write worm seeders, fill your tables with deterministic demo data, and run them with beak seed.
---

# Seeding

Seeders put rows in your tables so the panel has something to show. After this page you can write a plain seeder with fixed data, scale up to a shared context for realistic fake data, and run either with one command, getting the same database byte for byte on every run.

An empty admin panel is hard to judge. A seeder is a class that inserts demo rows; running it after your migrations gives you products to browse, orders to filter, and charts with real shapes. Beak uses worm's seeder machinery and discovers your seeders from `lib/seeders/`, so there is no list to register them in.

## What a seeder is

A seeder extends worm's `Seeder`. It declares a `name`, optionally the `Environment` it runs in and an execution `order`, and implements `run` against a `DatabaseAdapter`. Import it from `package:beak/migrations.dart`, the library that carries the schema and seeding half of worm.

```dart title="packages/worm/lib/src/seeder/seeder_base.dart"
abstract base class Seeder {
  /// Const constructor for subclasses.
  const Seeder();

  /// Identifier used by `db:seed`. Defaults to the type name.
  String get name;

  /// Environment(s) this seeder is allowed to run in.
  Environment get environment => Environment.all;

  /// Explicit execution order. Lower runs first; ties preserve
  /// registration order via the runner's stable sort.
  int get order => 0;

  /// When `true`, the runner executes [run] with model lifecycle
  /// events muted (via `Worm.withoutEvents`) so bulk inserts skip
  /// observer/hook overhead. Defaults to `false`.
  bool get muteEvents => false;

  /// Seed work.
  Future<void> run(DatabaseAdapter adapter);
}
```

`environment` defaults to `Environment.all`, so a seeder runs everywhere unless you narrow it (handy for keeping heavy demo data out of production). `order` sorts the registered seeders before they run.

The class needs a zero-argument `const` constructor, because `beak prepare` lists it as `StoreSeeder()` inside a `const` list. A seeder without one is reported by name and file rather than quietly skipped: a demo database that came up empty is a bad way to learn about a missing `const`.

### The simplest seeder

The store seeds a small, fixed catalog: two categories, three tags, two users, three products (one with a roast profile), and one order with two lines. It uses `adapter.insert` directly and gives every row a fixed, UUID-shaped primary key so tests and demos can name records.

```dart title="examples/store/lib/seeders/store_seeder.dart"
final class StoreSeeder extends Seeder {
  /// Creates the seeder.
  const StoreSeeder();

  @override
  String get name => 'StoreSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    final DateTime now = DateTime.utc(2026, 6, 30, 9, 30);

    await insert('categories', {
      'id': StoreSeedIds.categoryCoffee,
      'name': 'Coffee',
      'blurb': 'Beans, ground and whole.',
    });
    // ...the Gear category and three tags...
    await insert('users', {
      'id': StoreSeedIds.userAda,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'role': 'staff',
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    // ...a second user...
    await insert('products', {
      'id': StoreSeedIds.productEspresso,
      'name': 'Espresso Beans',
      'sku': 'COF-ESP-1KG',
      'summary': 'Dark roast, chocolate notes.',
      'price': 12.5,
      'stock': 42,
      'featured': true,
      'status': 'published',
      'published_at': now,
      'swatch': '#4B2E2B',
      'category_id': StoreSeedIds.categoryCoffee,
      'created_at': now,
      'updated_at': now,
    });
    // ...two more products, a roast profile, the product_tag pivot,
    // ...and one order with two lines.
  }
}
```

The ids are constants, not random:

```dart title="examples/store/lib/seeders/store_seeder.dart"
abstract final class StoreSeedIds {
  /// The "Coffee" category.
  static const categoryCoffee = '00000000-0000-4000-8000-000000000101';
  // ...
  /// Ada, the staff account.
  static const userAda = '00000000-0000-4000-8000-000000000301';
  // ...
  /// The espresso beans product.
  static const productEspresso = '00000000-0000-4000-8000-000000000401';
  // ...
}
```

Fixed keys make the whole seed assertable: the store's API suite looks up `StoreSeedIds.productEspresso` and knows exactly what it should find. The same constants are reused by `lib/server.dart`, whose demo accounts are the seeded users, so a login and a row policy line up with the data.

Inserts write the raw row map. A foreign key is its column (`category_id`), an enum column stores its `.name` (`'status': 'published'`), and a `DateTime` goes in as a `DateTime`. That is the shape [your migration created](migrations.md).

## Running seeders

There is nothing to register. `beak prepare` scans `lib/seeders/`, finds every class extending `Seeder`, and writes the list into the generated host:

```dart title="examples/store/lib/beak/server.g.dart"
  seeders: const [StoreSeeder()],
```

Run them after migrating, from the project directory:

```bash
beak seed
```

`beak seed` regenerates the wiring and then delegates to the project's generated `bin/migrate.dart`, which is the same `beakHost()` the server runs. Call that directly to see the runner's own output, or to pass a flag:

```bash
dart run bin/migrate.dart db:seed
```

```text
seeded  StoreSeeder
```

| Flag | Effect |
| --- | --- |
| `--class <Name>` | Run only the seeder whose `name` matches |
| `--force` | Skip the environment filter and run every seeder |
| `--env <name>` | Override the environment used for filtering |

If no seeder applies to the active environment, the runner prints `No seeders applicable to <env> environment.` and does nothing.

!!! tip "Start from a clean slate"
    `dart run bin/migrate.dart migrate:fresh --seed` drops everything, re-runs every migration, and seeds in one pass. It is the fastest way back to a known database while you are shaping a schema.

## Leveling up: a shared seed context

Fixed rows are what a teaching store wants. A 49-model showcase needs volume and variety without turning random, so `examples/superdashboard` builds every domain seeder on a shared `SeedContext`: a deterministically seeded faker, a fixed clock, a UUID minter, and thin insert helpers.

`SeedContext` is the showcase's own class, not something Beak ships. It is about seventy lines over worm's `FakerService` and `DatabaseAdapter`, both of which reach you through `package:beak/migrations.dart`. Copy it, trim it, or write your own; the pattern is the point.

```dart title="examples/superdashboard/lib/seeders/seed_context.dart"
--8<-- "examples/superdashboard/lib/seeders/seed_context.dart:SeedContext"
```

The toolkit at a glance:

| Member | Gives you |
| --- | --- |
| `insert` / `insertMany` | Write one row, or a batch |
| `selectAll(table)` | Read back rows another seeder inserted |
| `uuid()` | A deterministic UUID for a primary key |
| `between(lo, hi)` | An inclusive random integer |
| `money(lo, hi)` | A two-decimal amount |
| `daysAgo(maxDays)` / `around(days)` | A timestamp before, or near, the fixed `now` |
| `pick(values)` | A uniform random element |
| `weighted(weights)` | A key chosen by weight (8 published to 2 draft, say) |
| `chance(p)` | A boolean true with probability `p` |
| `faker` | The full `FakerService` for names, sentences, image URLs |

The constructor seeds the faker with the fixed `seed`, and every timestamp is measured from the fixed `now`. Same seed plus same clock equals the same rows every run: charts and calendars look identical, which makes screenshots and end-to-end assertions stable.

### The master seeder

Only one class in the showcase extends `Seeder`, which is also the only one discovery has to find. It builds a single shared context and runs the domain seeders through it in dependency order.

```dart title="examples/superdashboard/lib/seeders/demo_database_seeder.dart"
final class DemoDatabaseSeeder extends Seeder {
  /// Creates the master seeder.
  const DemoDatabaseSeeder();

  @override
  String get name => 'DemoDatabaseSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final ctx = SeedContext(adapter);
    await const PeopleSeeder().seed(ctx);
    await const CommerceSeeder().seed(ctx);
    await const EngagementSeeder().seed(ctx);
    await const AnalyticsSeeder().seed(ctx);
    // ...email, chat, calendar, files, invoices, kanban, content.
  }
}
```

One shared context means one continuous faker stream, so values stay unique across domains and the whole database reproduces byte for byte. People run first (the identity spine every foreign key points at), then Commerce, then Analytics, which rolls up the exact orders Commerce inserted so the dashboard reconciles.

### A domain seeder

A domain seeder is a plain class that takes the context. It does not extend `Seeder`: only the master does, which is why `beak prepare` lists one seeder rather than twelve. It leans on the toolkit for realistic-but-fixed rows.

```dart title="examples/superdashboard/lib/seeders/commerce_seeder.dart"
productRows.add({
  'id': id,
  'name': _productNames[index],
  'sku': 'SKU-${1000 + index}',
  'description': ctx.faker.paragraph(sentenceCount: 2),
  'price': price,
  'cost': double.parse((price * 0.55).toStringAsFixed(2)),
  'stock': ctx.between(0, 240),
  'status': ctx.weighted({
    ProductStatus.published.name: 8,
    ProductStatus.draft.name: 2,
    ProductStatus.scheduled.name: 1,
    ProductStatus.inactive.name: 1,
  }),
  'image': ctx.faker.imageUrl(width: 480, height: 480),
  'category_id': ctx.pick(categoryIds),
  'created_at': ctx.daysAgo(400),
  'updated_at': ctx.daysAgo(30),
});
```

Enum-backed columns store `.name` (matching a [`BeakEnumColumn`](../models/column-types.md), which persists by name), and `selectAll('users')` lets the order seeder pick real customer ids the people seeder already wrote. Dropping `demo_database_seeder.dart` into `lib/seeders/` is the whole registration; `beak seed` then fills all 49 tables in one pass.

!!! note "Determinism, restated"
    Nothing here is truly random. `SeedContext.seed` and `SeedContext.now` are constants, the faker is seeded from them, and the master runs one shared stream. Delete the database, migrate, seed, and you get the identical rows. That is what lets the demo apps ship screenshots and green end-to-end tests.

## Seeding inside a test

The generated host exposes its seeders, so a test seeds the same rows the CLI would without shelling out. The store's API suite migrates and seeds a fresh in-memory database in `setUpAll`:

```dart title="examples/store/test/api_scenario.dart"
      await MigrationRunner(
        adapter: adapter,
        migrations: host.migrations.toList(),
        seeders: host.seeders,
      ).fresh(seed: true);
```

`fresh(seed: true)` drops, migrates, and seeds. Because the seed is fixed, every assertion below it can name a record instead of searching for one.

## Continue reading

- [Migrations](migrations.md) create the tables a seeder fills.
- [Running the server](running-the-server.md) the generated host that lists your seeders.
- [Tutorial: First Flight](../tutorial/index.md) the same story, walked step by step.
- [Column types](../models/column-types.md) how enum and decimal columns store the values you seed.
- [Testing](../guides/testing.md) using a fresh in-memory adapter and seeders in tests.
