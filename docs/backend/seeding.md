---
title: Seeding
description: Write worm seeders, fill your tables with deterministic fake data through the SeedContext toolkit, and run them with db:seed.
---

# Seeding

Seeders put rows in your tables so the panel has something to show. After this page you can write a plain seeder with fixed data, level up to the `SeedContext` factory toolkit for realistic fake data, and run either with one command, getting the same database byte for byte on every run.

An empty admin panel is hard to judge. A seeder is a class that inserts demo rows; running it after your migrations gives you products to browse, orders to filter, and charts with real shapes. Beak uses worm's seeder machinery and adds a shared context that makes the fake data reproducible.

## What a seeder is

A seeder extends worm's `Seeder`. It declares a `name`, optionally the `Environment` it runs in and an execution `order`, and implements `run` against a `DatabaseAdapter`.

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

### The simplest seeder

The tutorial store seeds a small, fixed catalog: a couple of categories and tags, two users, three products, and one order. It uses `adapter.insert` directly and gives every row a fixed, UUID-shaped primary key so tests and demos can name records.

```dart title="apps/reference_admin_server/lib/src/seeders/reference_seeder.dart"
final class ReferenceSeeder extends Seeder {
  /// Creates the seeder.
  const ReferenceSeeder();

  @override
  String get name => 'ReferenceSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    await insert('categories', {
      'id': ReferenceSeedIds.categoryCoffee,
      'name': 'Coffee',
    });
    await insert('users', {
      'id': ReferenceSeedIds.userAda,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'active': true,
    });
    await insert('products', {
      'id': ReferenceSeedIds.productEspresso,
      'name': 'Espresso Beans',
      'description': 'Dark roast, chocolate notes.',
      'price': 12.5,
      'stock': 42,
      'status': 'published',
      'category_id': ReferenceSeedIds.categoryCoffee,
    });
    // ...tags, more products, the product_tag pivot, and one order.
  }
}
```

The IDs are constants, not random:

```dart title="apps/reference_admin_server/lib/src/seeders/reference_seeder.dart"
abstract final class ReferenceSeedIds {
  /// The "Coffee" category.
  static const categoryCoffee = '00000000-0000-4000-8000-000000000101';

  /// Ada, the active customer.
  static const userAda = '00000000-0000-4000-8000-000000000301';

  /// The espresso beans product.
  static const productEspresso = '00000000-0000-4000-8000-000000000401';
}
```

Fixed keys make the whole seed assertable: an end-to-end test can look up `productEspresso` by name and know exactly what it should find. Inserts write the raw row map (a foreign key is just its column, `category_id`), matching the [row shape your migration created](migrations.md).

## Running seeders

Registered seeders are passed to the same project worm CLI as the migrations. In `bin/worm.dart` the reference app lists one:

```dart title="apps/reference_admin_server/bin/worm.dart"
seeders: const [ReferenceSeeder()],
```

Run them after migrating, from the server app directory:

```bash
dart run bin/worm.dart db:seed
```

```text
seeded  ReferenceSeeder
```

The flags:

| Flag | Effect |
| --- | --- |
| `--class <Name>` | Run only the seeder whose `name` matches |
| `--force` | Skip the environment filter and run every seeder |
| `--env <name>` | Override the environment used for filtering |

If no seeder applies to the active environment, the runner prints `No seeders applicable to <env> environment.` and does nothing.

## Leveling up: the SeedContext toolkit

Fixed rows are perfect for a teaching store. A 49-model showcase needs volume and variety without turning random, so the showcase app builds every domain seeder on a shared `SeedContext`: a deterministically seeded faker, a fixed clock, a UUID minter, and thin insert helpers.

```dart title="apps/beak_superdashboard/lib/seeders/seed_context.dart"
final class SeedContext {
  /// Creates a context over [adapter] and seeds the faker.
  SeedContext(this.adapter) {
    faker.seed(seed);
  }

  /// The reproducibility seed shared by the faker and every derived value.
  static const int seed = 20260707;

  /// The demo's fixed "now" - every relative date is measured from here so
  /// screens look identical on every run.
  static final DateTime now = DateTime.utc(2026, 7, 7, 12);

  /// The adapter rows are written to.
  final DatabaseAdapter adapter;

  /// The seeded fake-data source.
  final FakerService faker = FakerService.instance;

  /// Inserts one row into [table].
  Future<void> insert(String table, Map<String, Object?> values) =>
      adapter.insert(InsertDescriptor(table: table, values: values));

  /// Inserts many [rows] into [table] in one batch (no-op when empty).
  Future<void> insertMany(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await adapter.insertMany(InsertManyDescriptor(table: table, rows: rows));
  }

  /// Reads back every row of [table].
  Future<List<Map<String, Object?>>> selectAll(String table) =>
      adapter.select(QueryDescriptor(table: table));

  /// A fresh deterministic UUID.
  String uuid() => faker.uuid();

  /// An inclusive integer in [lo]..[hi].
  int between(int lo, int hi) => faker.intBetween(lo, hi);

  /// A two-decimal amount in [lo]..[hi].
  double money(num lo, num hi) => faker.decimalBetween(lo, hi);

  /// A uniformly random element of [values].
  T pick<T>(List<T> values) => faker.element(values);

  /// A weighted random key of [weights].
  T weighted<T>(Map<T, int> weights) => faker.weighted(weights);

  /// `true` with probability [p].
  bool chance(double p) => faker.boolean(probability: p);
}
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

The constructor seeds the faker with the fixed `seed`, and every timestamp is measured from the fixed `now`. Same seed plus same clock equals the same rows every run: charts and calendars look identical, which makes screenshots and E2E assertions stable.

### The master seeder

Only one class extends `Seeder`: the master that builds a single shared context and runs the domain seeders through it in dependency order.

```dart title="apps/beak_superdashboard/lib/seeders/demo_database_seeder.dart"
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

A domain seeder is a plain class that takes the context. It does not extend `Seeder`: only the master does. It leans on the toolkit for realistic-but-fixed rows.

```dart title="apps/beak_superdashboard/lib/seeders/commerce_seeder.dart"
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

Enum-backed columns store `.name` (matching a [`BeakEnumColumn`](../models/column-types.md), which persists by name), and `selectAll('users')` lets the order seeder pick real customer IDs the people seeder already wrote. Registering `DemoDatabaseSeeder` in the showcase's `bin/worm.dart` and running `db:seed` fills all 49 tables in one pass.

!!! note "Determinism, restated"
    Nothing here is truly random. `SeedContext.seed` and `SeedContext.now` are constants, the faker is seeded from them, and the master runs one shared stream. Delete the database, migrate, seed, and you get the identical rows. That is what lets the demo apps ship screenshots and green E2E tests.

## Continue reading

- [Migrations](migrations.md) create the tables a seeder fills.
- [5. Seeding a flock of data](../tutorial/05-seeding-a-flock-of-data.md) the same story, walked step by step.
- [Column types](../models/column-types.md) how enum and decimal columns store the values you seed.
- [Testing](../guides/testing.md) using a fresh in-memory adapter and seeders in tests.
