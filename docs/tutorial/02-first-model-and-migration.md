---
title: 2. Your first model and migration
description: Define CategoryModel and its typed columns, write and register the migration, and create the categories table in Postgres.
---

# 2. Your first model and migration

By the end of this chapter the roastery has its first model, `CategoryModel`,
defined once in pure Dart, and a real `categories` table backing it in Postgres.
This is the smallest possible model on purpose: a lookup table of category names.
Everything richer builds on the shape you learn here.

Categories are how the roastery files its beans: Single Origin, Espresso Blends,
Decaf. Each is only an id and a name. Start there.

## A model is a class over typed columns

A Beak model is a `final class` extending `BeakModel`. It declares its table
name, which column stands in for a record in links and pickers, and its columns.
The columns themselves live in a companion `abstract final` class of `const`
constants, so both the model and, later, your custom code refer to them by name
and never by a string literal.

```dart
import 'package:beak_core/beak_core.dart';

/// Typed column constants of the categories resource.
abstract final class CategoryColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, name];
}

/// The categories resource: a flat lookup table products point at.
final class CategoryModel extends BeakModel {
  /// Creates the categories model.
  const CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => CategoryColumns.values;
}
```

Read the two columns closely, because they carry the whole idea.

- **`id`** is a `BeakStringColumn` with `visibleOn: {BeakContext.detail}`. It
  shows on the detail page but not in the table or the create form: nobody types
  a primary key. `BeakContext` is how one column decides which surfaces it
  appears on.
- **`name`** is `searchable` and `sortable`, and carries two rules,
  `BeakRequired()` and `BeakMaxLength(120)`. That single declaration is the whole
  contract for the field. It becomes the table column you can sort, the form
  input that refuses to submit empty or over-long, the REST validator that
  rejects the same on the server, and the CSV column on export. You write the
  rule once; every surface honors it.

That is the one-definition promise in miniature: `CategoryColumns.name` is
declared here and read everywhere, so you never reference `'name'` as a loose
string and never reach for `dynamic`.

!!! question "What this skipped"
    The real `category.dart` also declares a `hasMany` relationship to products.
    Products do not exist yet, so we leave it out until
    [Chapter 4](04-relationships-and-rich-columns.md), where products arrive and
    the relationship has something to point at.

## Write the migration

A model describes a table; it does not create one. In Beak, schema changes are
explicit worm migrations that you register and run yourself. They are never
applied automatically, so the database only ever changes when you say so.

Each migration is a `final class` extending `Migration` with a `name`, an
`upSchema` that builds the table, and a `downSchema` that drops it. Write the one
that creates `categories`:

```dart
import 'package:worm/worm.dart';

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

/// Every reference migration, in dependency order.
const List<Migration> the generated migration list = [
  CreateCategoriesTable(),
];
```

`table.idUuid()` adds the UUID primary key that `CategoryColumns.id` reads.
`table.string('name', length: 120)` mirrors the `BeakMaxLength(120)` rule on the
column: the app validates it, and the database enforces it. The
`the generated migration list` list is the ordered set the CLI will apply. It has one
entry today and grows as the store does.

## Register the model

Migrations create tables; the model registry is how the server and panel know
those tables exist as resources. `beakModels` is the single ordered list of
every model, and `buildBeakRegistry` turns it into the registry both halves
of the app read.

```dart
import 'package:beak_core/beak_core.dart';

import 'src/category.dart';

export 'src/category.dart';

/// Every reference model, in registration order.
const List<BeakModel> beakModels = [
  CategoryModel(),
];

/// Builds a [BeakModelRegistry] populated with every model in
/// [beakModels]: the single index both the server and the panel hand
/// to Beak.
BeakModelRegistry buildBeakRegistry() {
  final registry = BeakModelRegistry();
  for (final model in beakModels) {
    registry.register(model);
  }
  return registry;
}
```

Order here becomes the default resource and navigation order in the panel. As you
add models in later chapters, you add them to this list and to
`the generated migration list`, and everything downstream follows.

## Register the migration in the worm CLI

The reference server ships a project-aware worm CLI at `bin/migrate.dart`. It hands
the runner your `the generated migration list` (and, later, your seeders) and connects to
the Postgres URL your `.env` points at.

```dart title="examples/store/bin/migrate.dart"
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
    migrations: the generated migration list,
    seeders: const [StoreSeeder()],
  );
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
```

The `migrations: the generated migration list` line is the wiring: the CLI runs exactly
the migrations you registered, in order.

## Run the migration

Make sure the services from Chapter 1 are up (`melos run up`), then run the
migration from the server's own folder so it picks up that folder's `.env`:

```bash
cd examples/store
dart run bin/migrate.dart migrate
```

You should see one line, naming the migration it applied:

```text
migrated  20260701_000100_create_categories_table
```

!!! tip "Confirm it landed"
    `dart run bin/migrate.dart migrate:status` lists every migration with an
    applied marker, so you can see the schema state at a glance:

    ```text
    [x] 20260701_000100_create_categories_table  1  applied
    ```

!!! note "What just happened"
    - You defined `CategoryModel` and its typed columns once, in pure Dart, with
      validation rules attached to the `name` column.
    - You wrote a migration that creates the matching `categories` table, and
      registered it in `the generated migration list`.
    - You added the model to `beakModels`, the registry both the server and
      panel read.
    - `dart run bin/migrate.dart migrate` created the table. The roastery now has a
      real place to keep its categories.

The table exists, but nothing is serving it and nothing is showing it. The next
chapter turns this one model into a running backend and a live panel.

## Continue reading

- [3. The panel comes alive](03-the-panel-comes-alive.md) serve the model and
  open the panel.
- [Defining models](../models/defining-models.md) the full anatomy of a
  `BeakModel`.
- [Column basics](../models/column-basics.md) what a column configures, and the
  surfaces it drives.
- [Migrations](../backend/migrations.md) writing, registering, and running worm
  migrations.
- [The model registry](../models/the-registry.md) how `beakModels` becomes
  the index the whole app reads.
