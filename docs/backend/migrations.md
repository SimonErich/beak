---
title: Migrations
description: Write worm migrations by hand or derive them from your models, register them, and run them with the project worm CLI.
---

# Migrations

Migrations are how the shape of your database gets created. After this page you can write a migration by hand, derive one from a Beak model so it can never drift, register the set, and apply it with a single command.

Beak leaves schema to [worm](../reference/packages.md), its sibling ORM. A migration is a small class that says "make these tables" going up and "drop them" coming back down. Migrations are explicit and registered by hand. Nothing is auto-applied: your schema changes only when you run the command.

## What a migration is

A migration extends worm's `Migration`, has a `const` constructor, a unique timestamped `name`, and two methods: `upSchema` builds the schema, `downSchema` unwinds it.

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
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

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
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

A many-to-many join needs no surrogate key: the pair of foreign keys is the identity. The reference app writes it by hand.

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
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

The `unique` on the pair stops duplicate links; the cascading foreign keys clean up join rows when either side is deleted. You will meet a helper for exactly this shape below.

## Registering migrations

A migration only runs if it is in the list. Each app collects its migrations into a `const List<Migration>` in dependency order (parents before children):

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
/// Every reference migration, in dependency order.
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

That list is handed to the project worm CLI, `bin/worm.dart`, together with the seeders and an adapter factory that connects to the database `DATABASE_URL` points at:

```dart title="apps/reference_admin_server/bin/worm.dart"
Future<void> main(List<String> args) async {
  final config = BeakBackendConfig.fromEnv(environment: BeakEnv.resolve());
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
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
```

`postgresAdapterFromUrl` and `BeakBackendConfig.fromEnv` come from `beak_backend`; they are covered in [The data source seam](the-data-source-seam.md) and [Running the server](running-the-server.md).

## Running migrations

Run the CLI from the server app directory (`apps/reference_admin_server` for the tutorial store on port 8080, `apps/beak_superdashboard` for the showcase on port 8180). Applying pending migrations:

```bash
dart run bin/worm.dart migrate
```

```text
migrated  20260701_000100_create_categories_table
migrated  20260701_000200_create_tags_table
...
```

A second run prints `Nothing to migrate.` because worm skips names already in the ledger. The `migrate` command and its siblings:

| Command | What it does |
| --- | --- |
| `dart run bin/worm.dart migrate` | Apply every pending migration in order |
| `dart run bin/worm.dart migrate --pretend` | Print the compiled SQL without executing it |
| `dart run bin/worm.dart migrate --step=N` | Apply only the first `N` pending migrations |
| `dart run bin/worm.dart migrate:status` | List applied and pending migrations |
| `dart run bin/worm.dart migrate:rollback` | Undo the last batch (runs `downSchema`) |
| `dart run bin/worm.dart migrate:fresh` | Drop everything and re-run all migrations |
| `dart run bin/worm.dart migrate:refresh` | Roll back, then re-apply |

!!! warning "Migrations are never auto-applied"
    Booting the server does not touch your schema. A fresh database is empty until you run `migrate`. That is deliberate: production schema changes should be a decision you make, not a side effect of a deploy.

## Deriving schema from a model

Writing every column twice, once on the model and once in a migration, invites drift. The showcase app derives the migration from the model instead, with a helper that maps each typed `BeakColumn` to its schema type. `defineModelColumns` walks a model's columns and adds them to the table:

```dart title="apps/beak_superdashboard/lib/migrations/model_schema.dart"
void defineModelColumns(
  BlueprintTable table,
  BeakModel model, {
  Set<String> bigIntColumns = const {},
}) {
  final foreignKeys = <String>{
    for (final relation in model.relationships)
      if (relation is BeakBelongsTo) relation.foreignKey,
  };

  for (final column in model.columns) {
    if (column.key == 'id') {
      table.idUuid();
      continue;
    }
    if (foreignKeys.contains(column.key)) {
      table.uuid(column.key).makeNullable();
      continue;
    }
    final definition = switch (column) {
      BeakStringColumn(:final maxLength) => table.string(
        column.key,
        length: maxLength ?? 255,
      ),
      BeakEnumColumn() ||
      BeakColorColumn() => table.string(column.key, length: 40),
      BeakImageColumn() ||
      BeakFileColumn() => table.string(column.key, length: 512),
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakCustomColumn() => table.text(column.key),
      BeakIntColumn() =>
        bigIntColumns.contains(column.key)
            ? table.bigInteger(column.key)
            : table.integer(column.key),
      BeakDecimalColumn() => table.decimal(column.key),
      BeakBoolColumn() => table.boolean(column.key),
      BeakDateTimeColumn() => table.dateTime(column.key),
      BeakJsonColumn() => table.json(column.key),
    };
    if (column is BeakBoolColumn) {
      definition.withDefault(false);
    } else if (!column.rules.any((rule) => rule is BeakRequired)) {
      definition.makeNullable();
    }
  }

  if (model.softDeletes) {
    table.softDeletes();
  }
}
```

The rules it encodes:

- The `id` column becomes the UUID primary key.
- A column that backs a `BeakBelongsTo` relationship becomes a nullable `uuid` foreign-key column; you still declare the constraint yourself.
- A column carrying a [`BeakRequired`](../models/validation-rules.md) rule is `NOT NULL`; every other column is nullable.
- Booleans default to `false`.
- A byte-size column named in `bigIntColumns` uses `bigInteger` so gigabyte values do not overflow a 32-bit integer.
- Soft-deleting models get `softDeletes()` at the end.

Because the switch is exhaustive over every column type, a new column on the model is a compile error here until it is mapped: the schema cannot silently fall behind. A schema-parity test guards the match.

You call it inside `create` and layer any table-specific constraints on top:

```dart title="apps/beak_superdashboard/lib/migrations/commerce_migrations.dart"
await schema.create('products', (table) {
  defineModelColumns(table, const ProductModel());
  table.unique(['sku']);
  table.index(['status']);
  table.foreign(
    column: 'category_id',
    references: 'id',
    onTable: 'categories',
    onDelete: OnDelete.setNull,
  );
});
```

### definePivotTable

The keyless-join shape from earlier gets its own helper so every many-to-many looks the same:

```dart title="apps/beak_superdashboard/lib/migrations/model_schema.dart"
void definePivotTable(
  BlueprintTable table, {
  required String leftColumn,
  required String leftTable,
  required String rightColumn,
  required String rightTable,
}) {
  table.uuid(leftColumn);
  table.uuid(rightColumn);
  table.unique([leftColumn, rightColumn]);
  table.foreign(
    column: leftColumn,
    references: 'id',
    onTable: leftTable,
    onDelete: OnDelete.cascade,
  );
  table.foreign(
    column: rightColumn,
    references: 'id',
    onTable: rightTable,
    onDelete: OnDelete.cascade,
  );
}
```

```dart title="apps/beak_superdashboard/lib/migrations/commerce_migrations.dart"
await schema.create(
  'product_tag',
  (table) => definePivotTable(
    table,
    leftColumn: 'product_id',
    leftTable: 'products',
    rightColumn: 'tag_id',
    rightTable: 'tags',
  ),
);
```

Both helpers live in the app, not in a Beak package: they are a pattern you are free to copy and bend, not framework API. The reference app hand-writes its migrations to show the DSL plainly; the showcase derives them to keep 49 models honest. Either way, the migration list you register and the command you run are the same.

## Continue reading

- [Seeding](seeding.md) fill the tables you just created with deterministic demo data.
- [Relationships](../models/relationships.md) the `BeakOnDelete` rules your foreign keys mirror.
- [Defining models](../models/defining-models.md) the typed columns `defineModelColumns` reads.
- [Running the server](running-the-server.md) how `DATABASE_URL` and the adapter reach the CLI.
