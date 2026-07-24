---
title: 5. Seeding a flock of data
description: Write a deterministic seeder that fills the store with categories, tags, users, products, and an order, then meet the factory toolkit for larger data sets.
---

# 5. Seeding a flock of data

Empty tables make a quiet panel. By the end of this chapter your store holds a
small, repeatable catalog: two categories, three tags, two customers, three
products (tagged and filed), and one order with two line items. The panel stops
showing "no records" and starts showing coffee.

A seeder is plain Dart that inserts rows. Because it uses fixed ids, it produces
the same database every run, which is what makes it safe to assert against in
tests and pleasant to demo.

## Finish the schema first

The seeder writes customers and orders, so those tables need to exist. Add the
last three migrations (users, orders, order items) alongside the ones from
chapter 4, then register the complete list.

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
/// Creates the users table.
final class CreateUsersTable extends Migration {
  const CreateUsersTable();

  @override
  String get name => '20260701_000300_create_users_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('users', (table) {
      table.idUuid();
      table.string('name', length: 120);
      table.string('email');
      table.boolean('active').withDefault(true);
      table.unique(['email']);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('users', ifExists: true);
}

/// Creates the orders table.
final class CreateOrdersTable extends Migration {
  const CreateOrdersTable();

  @override
  String get name => '20260701_000600_create_orders_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('orders', (table) {
      table.idUuid();
      table.string('reference', length: 40);
      table.decimal('total');
      table.dateTime('placed_at').makeNullable();
      table.uuid('user_id').makeNullable();
      table.unique(['reference']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('orders', ifExists: true);
}

/// Creates the order-items table.
final class CreateOrderItemsTable extends Migration {
  const CreateOrderItemsTable();

  @override
  String get name => '20260701_000700_create_order_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('order_items', (table) {
      table.idUuid();
      table.string('label', length: 160);
      table.integer('quantity').withDefault(1);
      table.decimal('unit_price');
      table.uuid('order_id');
      table.uuid('product_id').makeNullable();
      table.foreign(
        column: 'order_id',
        references: 'id',
        onTable: 'orders',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('order_items', ifExists: true);
}
```

Now the `referenceMigrations` list is complete, in dependency order (a table's
foreign keys always point at a table declared before it):

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
const List<Migration> referenceMigrations = [
  CreateCategoriesTable(),
  CreateTagsTable(),
  CreateUsersTable(),
  CreateProductsTable(),
  CreateProductTagTable(),
  CreateOrdersTable(),
  CreateOrderItemsTable(),
];
```

Apply the three new ones:

```bash
cd apps/reference_admin_server
dart run bin/worm.dart migrate
```

```text
migrated  20260701_000300_create_users_table
migrated  20260701_000600_create_orders_table
migrated  20260701_000700_create_order_items_table
```

## Fixed ids, so the flock stays put

Random ids make every run different and tests impossible. Declare the ids up
front as constants. They are UUID-shaped (the columns are real `uuid` columns)
but fixed, so any seeder or test can reference a record by name.

```dart title="apps/reference_admin_server/lib/src/seeders/reference_seeder.dart"
import 'package:worm/worm.dart';

/// Deterministic primary keys of the seeded catalog.
abstract final class ReferenceSeedIds {
  static const categoryCoffee = '00000000-0000-4000-8000-000000000101';
  static const categoryGear = '00000000-0000-4000-8000-000000000102';
  static const tagHot = '00000000-0000-4000-8000-000000000201';
  static const tagNew = '00000000-0000-4000-8000-000000000202';
  static const tagSale = '00000000-0000-4000-8000-000000000203';
  static const userAda = '00000000-0000-4000-8000-000000000301';
  static const userLinus = '00000000-0000-4000-8000-000000000302';
  static const productEspresso = '00000000-0000-4000-8000-000000000401';
  static const productGrinder = '00000000-0000-4000-8000-000000000402';
  static const productTeaser = '00000000-0000-4000-8000-000000000403';
  static const order1001 = '00000000-0000-4000-8000-000000000601';
}
```

## The seeder

A `Seeder` overrides one method: `run`, which receives the raw database adapter.
A tiny local `insert` helper keeps each row to one readable line. The order of
inserts matters: a product references a category, so categories go in first; an
order references a user, so users go in first.

```dart title="apps/reference_admin_server/lib/src/seeders/reference_seeder.dart"
/// Seeds a small, deterministic catalog.
final class ReferenceSeeder extends Seeder {
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
    await insert('categories', {
      'id': ReferenceSeedIds.categoryGear,
      'name': 'Gear',
    });

    await insert('tags', {'id': ReferenceSeedIds.tagHot, 'name': 'hot'});
    await insert('tags', {'id': ReferenceSeedIds.tagNew, 'name': 'new'});
    await insert('tags', {'id': ReferenceSeedIds.tagSale, 'name': 'sale'});

    await insert('users', {
      'id': ReferenceSeedIds.userAda,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'active': true,
    });
    await insert('users', {
      'id': ReferenceSeedIds.userLinus,
      'name': 'Linus Cove',
      'email': 'linus@example.com',
      'active': false,
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

    await insert('product_tag', {
      'product_id': ReferenceSeedIds.productEspresso,
      'tag_id': ReferenceSeedIds.tagHot,
    });

    await insert('orders', {
      'id': ReferenceSeedIds.order1001,
      'reference': 'ORD-1001',
      'total': 114.0,
      'placed_at': DateTime.utc(2026, 6, 30, 9, 30),
      'user_id': ReferenceSeedIds.userAda,
    });
    await insert('order_items', {
      'id': '00000000-0000-4000-8000-000000000701',
      'label': '2× Espresso Beans',
      'quantity': 2,
      'unit_price': 12.5,
      'order_id': ReferenceSeedIds.order1001,
      'product_id': ReferenceSeedIds.productEspresso,
    });
    // The remaining products, pivot rows, and the second line item follow the
    // same shape; see reference_seeder.dart for the full set.
  }
}
```

Notice the status is the plain string `'published'`, not the enum. The seeder
speaks the storage layer's language (raw rows into raw tables), which is why it
takes the adapter directly rather than going through a model. The `BeakEnumColumn`
you declared earlier is what decodes that string back into a typed
`ProductStatus` everywhere it is read.

## Register and run

The project's worm CLI lives in `bin/worm.dart`. It already passes the store's
migrations to the CLI context; add the seeder to the `seeders` list next to
them.

```dart title="apps/reference_admin_server/bin/worm.dart"
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment,
    now: DateTime.now,
    adapterFactory: () async {
      final adapter = postgresAdapterFromUrl(config.databaseUrl);
      await adapter.connect();
      return adapter;
    },
    migrations: referenceMigrations,
    seeders: const [ReferenceSeeder()],
  );
```

Run the seeders:

```bash
dart run bin/worm.dart db:seed
```

```text
seeded  ReferenceSeeder
```

Restart the panel and the tables are full: three products with prices and status
badges, two customers, one order. Espresso Beans shows its `hot` and `new`
badges; the order links back to Ada.

!!! note "What just happened"
    - A `Seeder` inserted rows through the raw adapter, in dependency order, so
      every foreign key resolves.
    - Fixed `ReferenceSeedIds` make the seed reproducible: the same database
      every run, safe to assert against in tests.
    - Registering the seeder in `bin/worm.dart` is all `db:seed` needs to find
      and run it.

## Leveling up: the factory toolkit

Hand-writing rows is right for a teaching catalog. For a demo with hundreds of
orders you want generated data that still reproduces byte-for-byte. The
**showcase app** (`beak_superdashboard`) does this with a shared `SeedContext`:
a deterministically seeded faker, a fixed clock, a UUID minter, and batch insert
helpers.

```dart title="apps/beak_superdashboard/lib/seeders/seed_context.dart"
final class SeedContext {
  SeedContext(this.adapter) {
    faker.seed(seed);
  }

  static const int seed = 20260707;
  static final DateTime now = DateTime.utc(2026, 7, 7, 12);

  final DatabaseAdapter adapter;
  final FakerService faker = FakerService.instance;

  Future<void> insert(String table, Map<String, Object?> values) =>
      adapter.insert(InsertDescriptor(table: table, values: values));

  Future<void> insertMany(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) {
      return;
    }
    await adapter.insertMany(InsertManyDescriptor(table: table, rows: rows));
  }

  String uuid() => faker.uuid();
  int between(int lo, int hi) => faker.intBetween(lo, hi);
  double money(num lo, num hi) => faker.decimalBetween(lo, hi);
  T pick<T>(List<T> values) => faker.element(values);
  T weighted<T>(Map<T, int> weights) => faker.weighted(weights);
}
```

Because the faker is seeded once, the whole stream of "random" values is fixed.
A domain seeder then builds rows in batches and hands the context weighted odds
instead of hard-coded values:

```dart title="apps/beak_superdashboard/lib/seeders/commerce_seeder.dart"
productRows.add({
  'id': id,
  'name': _productNames[index],
  'price': price,
  'stock': ctx.between(0, 240),
  'status': ctx.weighted({
    ProductStatus.published.name: 8,
    ProductStatus.draft.name: 2,
  }),
  'category_id': ctx.pick(categoryIds),
});
// ...build every product row, then insert them in one batch:
await ctx.insertMany('products', productRows);
```

A master seeder builds one context and runs each domain seeder through it, so
the whole database shares a single faker stream and reconciles across domains:

```dart title="apps/beak_superdashboard/lib/seeders/demo_database_seeder.dart"
  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final ctx = SeedContext(adapter);
    await const PeopleSeeder().seed(ctx);
    await const CommerceSeeder().seed(ctx);
    // ...more domain seeders, in dependency order
  }
```

Your store does not need this yet. When it grows past what you want to type by
hand, this is the pattern to reach for. The `ProductStatus` values in the
showcase snippet are the showcase's own enum; keep your store's rows on your
store's models.

## Continue reading

- [6. Filters, actions, and view modes](06-filters-actions-and-view-modes.md)
  make the now-populated tables searchable and give them a row action and a board
  view.
- [Seeding](../backend/seeding.md) the full seeding surface: environments,
  `--force`, targeting one seeder, and the factory pattern in depth.
- [CLI commands](../reference/cli-commands.md) every worm command, including
  `migrate:fresh --seed` for rebuilding from scratch.
