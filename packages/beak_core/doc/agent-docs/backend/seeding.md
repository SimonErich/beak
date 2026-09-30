# Seeding

> Write a seeder that fills a database with demo rows, is safe to run twice, and stays out of production unless you say otherwise.

A seeder puts rows into a database. After this page you can write one that is safe to run twice, run it in development without touching production, and test that it keeps its promise.

An empty admin panel is a poor way to check that an admin panel works. A seeder gives every teammate, every CI run and every fresh laptop the same handful of customers, products and orders. It is plain Dart in `lib/seeders/`, and it runs when you type a command.

## At a glance

| Question | Answer |
| --- | --- |
| Where does it live | `lib/seeders/`, one class per file. `beak prepare` finds it and registers its const constructor |
| What is it | A worm `Seeder`, imported through `package:beak/migrations.dart` |
| What you implement | `name` and `run(DatabaseAdapter adapter)` |
| How it runs | `beak seed`, `beak migrate fresh --seed`, and automatically for `sqlite::memory:` |
| Does Beak remember what ran | No. Every eligible seeder runs every time you ask |
| Where it runs | Every environment, until you restrict it |

## The smallest seeder

The seeder checks whether its row exists, then inserts it. The typed model gives it the table and the fields, so no string names a column:

```dart
// Illustrative: a file of your own, lib/seeders/product_seeder.dart.
import 'package:beak/migrations.dart';

import '../beak/registry.g.dart';
import '../resources/products/models/product.dart';

/// Demo products, safe to run twice.
final class ProductSeeder extends Seeder {
  /// Creates the seeder.
  const ProductSeeder();

  @override
  String get name => 'ProductSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final data = WormDataSource(buildBeakRegistry(), adapter: adapter);
    const id = '00000000-0000-4000-8000-000000000002';
    if (await data.find(const ProductModel(), id) != null) return;
    await data.insert(const ProductModel(), [
      ProductModel.id.to(id),
      ProductModel.name.to('Grinder'),
      ProductModel.price.to(48),
    ]);
  }
}
```

Run the migrations first, then the seed:

```console
$ beak migrate
$ beak seed
seeded  ProductSeeder
$ beak seed
seeded  ProductSeeder
```

Both runs print `seeded`, and the second one added nothing. The line means the seeder ran, not that it wrote a row. Whether it wrote one is the seeder's business, and the next section is about making that business boring.

## Make it safe to run twice

`beak seed` keeps no list of what it has run. You will call it again after a migration, after a teammate's pull, and on a database that already holds real edits. Decide in advance what a second run does to a row that exists:

| Choice | When | How |
| --- | --- | --- |
| Skip it | Demo data users may have edited | Look the row up by its stable id first, insert only when it is missing |
| Update it | Reference data you own, like tax rates | Look it up, then `data.patch(...)` the fields you own |
| Refuse | Data that must be exactly what you wrote | Throw when a row exists with different content |

A stable id is what makes any of these possible, and it is not enough alone. An unconditional insert of a fixed id succeeds once and fails on the second run with a unique-constraint error.

The shop skips. Its helper looks the id up before it inserts, so re-running fills in fixture rows that are missing and leaves the ones somebody edited alone:

```dart title="examples/clean_beak_config/lib/seeders/shop_seeder.dart"
/// Idempotent demonstration data. Existing rows and user edits are preserved.
final class ShopSeeder extends Seeder {
  /// Creates the deterministic demo seeder.
  const ShopSeeder();

  @override
  String get name => 'ShopSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      final id = values['id'];
      if (id == null) throw StateError('A seed row needs an identity.');
      if (await adapter.selectOne(
            QueryDescriptor(
              table: table,
              where: const Field<Object>('id').eq(id),
              limit: 1,
            ),
          ) !=
          null) {
        return;
      }
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }
```

Its ids are named constants in `ShopSeedIds`, so tests and related fixtures refer to the same record without searching by a label that a translation might change.

Foodio skips at a coarser grain. It seeds a whole reference dataset in one transaction and writes a version row into `app_settings` at the end. Later runs find that row and return before touching anything:

```dart title="examples/foodio-adminpanel/lib/seeders/foodio_seeder.dart"
/// Reproducible, real records. Re-running never overwrites a user's demo changes.
final class FoodioSeeder extends Seeder {
  /// Seeds once without overwriting later operator changes.
  const FoodioSeeder();
  @override
  String get name => 'FoodioSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    final done = await adapter.selectOne(
      QueryDescriptor(
        table: 'app_settings',
        where: const Field<String>('key').eq('foodioSeedVersion'),
        limit: 1,
      ),
    );
    if (done != null) return;
    await adapter.transaction((transaction) async {
      final seed = _FoodioSeed(transaction);
      await seed.references();
      await seed.orders();
      await seed.activity();
      await seed.flush();
      await seed.insert('app_settings', {
        'id': 'seed-version',
        'key': 'foodioSeedVersion',
        'value': '1',
        'description': 'Gabel September 2026 reference dataset',
      });
    });
  }
}
```

Use the shop's pattern for a handful of rows and Foodio's for a dataset whose rows depend on each other. The version row also gives you a way to ship a new seed later: bump the value, and the old one no longer counts as done.

## Keep demo data out of production

A seeder runs in every environment unless it says otherwise, and that includes production. Restrict a demo seeder to development by overriding `environment` with a value of worm's `Environment` enum (`development`, `staging`, `production`, `testing`, `all`):

```dart
  // Illustrative: one line added to the seeder above.
  @override
  Environment get environment => Environment.development;
```

The active environment comes from `WORM_ENV`, defaulting to `development`. `beak seed` reads it from the shell over the project's `.env`, the way `beak migrate fresh` does, so a `WORM_ENV=production` line in `.env` filters the seeders too. Here is what the flags do with two seeders, one restricted to development and one left at `all`:

```console
$ beak seed
seeded  ProductSeeder
seeded  TypedProductSeeder
$ WORM_ENV=production beak seed
seeded  ProductSeeder
$ WORM_ENV=production beak seed --force
seeded  ProductSeeder
seeded  TypedProductSeeder
$ beak seed --class TypedProductSeeder
seeded  TypedProductSeeder
$ beak seed --env staging
seeded  ProductSeeder
```

`--env` changes the environment the filter uses without changing `WORM_ENV`. `--force` ignores the filter for every seeder, and `--class` runs one seeder by name and ignores it as well. When nothing is eligible, the command says `No seeders applicable to development environment.` and exits `0`.

Set `WORM_ENV=production` in the environment of your deploy step. A stray `beak seed` on the wrong shell then skips the demo seeders instead of adding a "Grinder" to your customer's catalog.

## What a seeder does not do

A seeder writes below the panel's rules. Nothing validates the row, nothing fills defaults, nothing mints an id or stamps `created_at`, and a model's `behavior` does not run. `data.insert` puts exactly the values you list. Two consequences:

- Exact money and other semantic fields have a stored form that is not the number you type. The typed `field.to(value)` encodes it. In a raw row you encode it yourself, which is what the shop's `_stored` does, so a seeded amount matches what the API would have written:

```dart title="examples/clean_beak_config/lib/seeders/shop_seeder.dart"
/// The stored value of the exact [amount] for [field], such as `'12.50'`.
///
/// Amounts are written the way the API writes them, so a seeded row is
/// indistinguishable from one saved through the panel.
Object? _stored(BeakScalarField<BeakDecimal> field, String amount) =>
    field.encode(BeakDecimal.parse(amount)).raw;
```

- Columns you leave out stay `NULL`, including timestamps, unless the column has a database default. Foodio fills declared defaults with `BeakValidation().applyDefaults` and stamps `created_at` and `updated_at` itself. Do the same when a list sorts by them.

When the data has to obey your business rules, do not seed it as rows. Send a graph commit through the API, or build the plan in a test, and the same rules that guard the form guard the seed.

## Test that it repeats

The shop's migration test starts from an old schema, inserts a customer's edit, runs the seeder, and asserts that the edit survived:

```dart title="examples/clean_beak_config/test/shop_migration_test.dart"
await const ShopSeeder().run(adapter);
final beans = await adapter.selectOne(
  QueryDescriptor(
    table: 'products',
    where: const Field<String>('id').eq(ShopSeedIds.beans),
  ),
);
expect(beans?['name'], 'My existing beans');
```

Copy that shape for your own seeder: run it twice, change a seeded row between the runs, and assert that the change is still there. The API tests use a separate in-memory database, so their resets never touch your `beak.db`.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| `beak seed` runs every eligible seeder on every call | Idempotence is your seeder's job. Nothing tracks what ran |
| `seeded` means "ran", not "wrote" | A second run prints the same line and may add nothing |
| Default environment is `Environment.all` | An unrestricted seeder runs in production too |
| `beak seed` reads `WORM_ENV` from the shell over `.env` | It passes the value to worm as `--env`, so an explicit `--env` beats both. Running `dart run bin/migrate.dart db:seed` directly reads the shell only, and so does `beak migrate fresh --seed` |
| `--force` ignores the environment filter | It also runs the demo seeders you restricted. Do not put it in a deploy script |
| Seeders skip validation, defaults, ids, timestamps and behavior | Provide what a form and a service would have provided |
| A seeder that throws stops the run | Seeders before it have already written. Wrap related rows in `adapter.transaction`, as Foodio does |
| The migrations must have run | A seeder on an empty database fails on the first missing table |
| Seeders run in the order `beak prepare` listed them, or by `order` | Override `int get order` (lower runs first) when one seeder depends on another |

## Verify it

Run the seed twice and count. The second count must equal the first:

```console
$ beak seed
$ sqlite3 beak.db 'select count(*) from products'
1
$ beak seed
$ sqlite3 beak.db 'select count(*) from products'
1
```

Then edit a seeded row in the panel, run `beak seed` again, and confirm your edit is still there. On a database you care about, do the same with `WORM_ENV=production` and confirm the demo seeders print nothing.

## Reference

- `packages/worm/lib/src/seeder/seeder_base.dart`: `Seeder` with `name`, `environment`, `order`, `muteEvents` and `run`.
- `packages/beak_cli/lib/src/commands/dev_command.dart`: the `beak seed` command and its flags.
- `packages/beak_core/lib/src/data/beak_data_source_writes.dart`: the typed `insert` and `patch`.
- [CLI commands](../reference/cli-commands.md#beak-seed) lists the flags of `beak seed`.

## Continue reading

- [Migrations](migrations.md) the schema a seeder writes into.
- [Databases](databases.md) `sqlite::memory:` and why the server seeds it for you.
- [Testing](../shipping/testing.md) running seeders inside a test database.
- [Running the server](running-the-server.md) where the host lists the seeders it found.
