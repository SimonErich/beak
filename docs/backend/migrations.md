---
title: Migrations
description: Write worm migrations by hand or derive them from your models, register them, and run them with the project worm CLI.
---

# Migrations

Migrations are how the shape of your database gets created. After this page you can write a migration by hand, derive one from a Beak model so it can never drift, register the set, and apply it with a single command.

Beak leaves schema to [worm](../reference/packages.md), its sibling ORM. A migration is a small class that says "make these tables" going up and "drop them" coming back down. Migrations are explicit and registered by hand. Nothing is auto-applied: your schema changes only when you run the command.

## What a migration is

A migration extends worm's `Migration`, has a `const` constructor, a unique timestamped `name`, and two methods: `upSchema` builds the schema, `downSchema` unwinds it.

```dart
/// Creates the categories lookup table.
final class CreateCategoriesTable extends Migration {
  /// Creates the migration.
  const CreateCategoriesTable();

  @override
  String get name => '20260701_000100_create_categories_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('categories', (table) {
      table.idUuid();
      table.string('name', length: 120);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('categories', ifExists: true);
}
```

The `name` doubles as the ledger key and the ordering key: worm records applied names in a migrations table and runs pending ones in ascending name order, so the timestamp prefix keeps dependencies in line. `downSchema` is the exact inverse, used by rollbacks.

!!! note "What just happened"
    `schema.create(table, builder)` opens a `BlueprintTable` you describe column by column. `schema.drop(table, ifExists: true)` removes it without error if it was never created. Everything else on this page is variations on those two calls.

## The schema DSL

Inside a `create` block you call methods on the `table` blueprint. Each returns a column definition you can chain modifiers onto.

| Call | Column |
| --- | --- |
| `table.idUuid()` | UUID primary key named `id` |
| `table.string('name', length: 120)` | `VARCHAR`, length optional (defaults to 255) |
| `table.text('description')` | unbounded text |
| `table.integer('stock')` / `table.bigInteger('size')` | 32-bit / 64-bit integer |
| `table.decimal('price')` | fixed-precision decimal |
| `table.boolean('active')` | boolean |
| `table.uuid('category_id')` | plain UUID column (for foreign keys) |
| `table.dateTime('placed_at')` | timestamp |
| `table.json('payload')` | JSON column |
| `table.timestamps()` | adds `created_at` and `updated_at` |
| `table.softDeletes()` | adds the nullable `deleted_at` marker |

Two modifiers chain onto a column: `.makeNullable()` allows `NULL`, and `.withDefault(value)` sets a default. Three table-level calls add constraints: `.unique([...])`, `.index([...])`, and `.foreign(...)`.

Here is a fuller table that uses most of them. Note the foreign key, the index, and the soft-delete/timestamp pair:

```dart
@override
Future<void> upSchema(Schema schema) async {
  await schema.create('products', (table) {
    table.idUuid();
    table.string('name');
    table.text('description').makeNullable();
    table.decimal('price');
    table.integer('stock').withDefault(0);
    table.string('status', length: 20).withDefault('draft');
    table.string('image').makeNullable();
    table.uuid('category_id').makeNullable();
    table.timestamps();
    table.softDeletes();
    table.index(['status']);
    table.foreign(
      column: 'category_id',
      references: 'id',
      onTable: 'categories',
      onDelete: OnDelete.setNull,
    );
  });
}
```

`onDelete` takes worm's `OnDelete` enum: `cascade`, `restrict`, `setNull`, `setDefault`, `noAction`, and `ormCascade`. Beak's own [`BeakOnDelete`](../models/relationships.md) mirrors these one to one, so the rule you declare on a relationship matches the constraint your migration writes.

### Pivot tables

A many-to-many join needs no surrogate key: the pair of foreign keys is the identity. Spelled out, it looks like this:

```dart
@override
Future<void> upSchema(Schema schema) async {
  await schema.create('product_tag', (table) {
    table.uuid('product_id');
    table.uuid('tag_id');
    table.unique(['product_id', 'tag_id']);
    table.foreign(
      column: 'product_id',
      references: 'id',
      onTable: 'products',
      onDelete: OnDelete.cascade,
    );
    table.foreign(
      column: 'tag_id',
      references: 'id',
      onTable: 'tags',
      onDelete: OnDelete.cascade,
    );
  });
}
```

The `unique` on the pair stops duplicate links; the cascading foreign keys clean up join rows when either side is deleted. You rarely type that out: `BeakBlueprint.createPivot` writes this shape from the relationship, and the generated pivot migration below calls it.

## Registering migrations

Nothing. `beak prepare` scans `lib/migrations/`, orders the classes it finds
by their `name`, and writes the list into `lib/beak/server.g.dart`:

```dart title="examples/store/lib/beak/server.g.dart"
BeakServeHost beakHost({Map<String, String>? environment}) => BeakServeHost(
  environment: environment,
  registry: buildBeakRegistry(),
  migrations: const [
    CreateCategoriesTable(),
    CreateUsersTable(),
    CreateOrdersTable(),
    CreateProductsTable(),
    CreateOrderItemsTable(),
    CreateRoastProfilesTable(),
    CreateTagsTable(),
    CreateProductTagTable(),
  ],
  seeders: const [StoreSeeder()],
  configure: server.beakServer,
);
```

Adding a migration means adding a file. Deleting one means deleting a file.
There is no list to keep in step, which is the list that used to be wrong.

## Running migrations

`bin/migrate.dart` is generated too, and is one line. Run it from the project
directory:

```bash
dart run bin/migrate.dart migrate
```

```text
migrated  20260727_152054_create_categories_table
migrated  20260727_152055_create_users_table
...
```

A second run prints `Nothing to migrate.` because worm skips names already in
the ledger. The `migrate` command and its siblings:

| Command | What it does |
| --- | --- |
| `dart run bin/migrate.dart migrate` | Apply every pending migration in order |
| `dart run bin/migrate.dart migrate --pretend` | Print the compiled SQL without executing it |
| `dart run bin/migrate.dart migrate --step=N` | Apply only the first `N` pending migrations |
| `dart run bin/migrate.dart migrate:status` | List applied and pending migrations |
| `dart run bin/migrate.dart migrate:rollback` | Undo the last batch (runs `downSchema`) |
| `dart run bin/migrate.dart migrate:fresh` | Drop everything and re-run all migrations |
| `dart run bin/migrate.dart migrate:refresh` | Roll back, then re-apply |
| `dart run bin/migrate.dart db:seed` | Run the registered seeders |

!!! warning "Migrations are never auto-applied"
    Booting the server does not touch your schema. A fresh database is empty
    until you run `migrate`. That is deliberate: a production schema change
    should be a decision you make, not a side effect of a deploy.

## The migration Beak writes for you

You rarely write the first migration for a resource. `beak prepare` notices
that a schema class has no migration and writes one:

```dart title="examples/store/lib/migrations/create_products_table.dart"
final class CreateProductsTable extends Migration {
  /// Creates the migration.
  const CreateProductsTable();

  @override
  String get name => '20260727_152057_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('products', (table) {
      BeakBlueprint.defineColumns(table, const ProductModel());
      BeakBlueprint.defineForeignKeys(table, const ProductModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}
```

Two things to notice.

**It is written once and then it is yours.** Beak never rewrites a migration
it has written. The file is ordinary source you can edit, and `beak prepare`
leaves it alone from then on.

**It reads the model rather than repeating it.** `BeakBlueprint.defineColumns`
walks the model's columns and adds each one with the right storage type,
nullability, length, index and unique constraint; `defineForeignKeys` adds the
constraints its belongs-to relationships imply, each with the `onDelete` rule
the relationship declared. Every belongs-to key is indexed without being asked,
because a foreign key you filter and join on and never index is the slow query
you will find later.

That is why adding a column to a schema class changes the table with no second
edit: the DDL is derived from the same declaration the API and the panel read.

A `@BelongsToMany` relationship gets the same treatment, through
`BeakBlueprint.createPivot`. It reads the pivot table name and both key columns
off the relationship, so the join table and the relationship cannot disagree. It
also adds an index on the right-hand key, which the composite `unique` does not
cover, so a many-to-many is fast from both sides:

```dart title="examples/store/lib/migrations/create_product_tag_table.dart"
@override
Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
  schema,
  ProductRelations.tags,
  ownerTable: 'products',
);

@override
Future<void> downSchema(Schema schema) async =>
    schema.drop('product_tag', ifExists: true);
```

## Changing a table later

The generated migration creates a table. Changing one is a migration you
write, and `beak make:migration` scaffolds the shape:

```bash
beak make:migration AddNotesToOrders
```

!!! tip "Adding a field to a resource that is already live"
    That is the common case, and `--from-drift` writes it for you: it reads
    the database, compares it against the schema classes, and fills the body
    in with the columns the table is missing.

    ```bash
    beak make:migration AddStockToProducts --from-drift
    beak migrate
    ```

    It reads the database rather than the migrations because a Beak migration
    never names its columns. See
    [`--from-drift`](../reference/cli-commands.md#-from-drift).

```dart
final class AddNotesToOrders extends Migration {
  /// Creates the migration.
  const AddNotesToOrders();

  @override
  String get name => '20260728_090000_add_notes_to_orders';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.alter('orders', (table) {
      table.text('notes').makeNullable();
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    await schema.alter('orders', (table) {
      table.dropColumn('notes');
    });
  }
}
```

`schema.alter` reaches the same blueprint `schema.create` does, so adding a
column, an index or a foreign key reads the same either way. SQLite supports
adding and dropping columns and indexes; changing a column's type there throws
a typed exception naming the limitation, rather than silently rebuilding the
table and losing your triggers.

## Continue reading

- [Seeding](seeding.md) fill the tables you just created with deterministic demo data.
- [Relationships](../models/relationships.md) the `BeakOnDelete` rules your foreign keys mirror.
- [Defining models](../models/defining-models.md) the typed columns `defineModelColumns` reads.
- [Running the server](running-the-server.md) how `DATABASE_URL` and the adapter reach the CLI.
