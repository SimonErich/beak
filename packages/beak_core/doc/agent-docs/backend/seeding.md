# Seeding

> Populate repeatable development fixtures while preserving existing records.

A seeder extends Worm's `Seeder`, implements `run(DatabaseAdapter adapter)` and
provides a stable `name`. Import the contract through `package:beak/migrations.dart`.
Place seeders in `lib/seeders/`; `beak prepare` discovers them and registers their
zero-argument constructors in the generated host.

```sh
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
```

Seeders can declare an environment and execution order. Keep demonstration data
out of production unless that is an explicit deployment decision.

## The canonical shop

`examples/clean_beak_config/lib/seeders/shop_seeder.dart` seeds customers, delivery
profiles, categories and attribute definitions, products and variants, taxes,
vouchers, a confirmed order, an illustrative invoice and fulfillment metadata.
Stable identifiers in `ShopSeedIds` let tests and related fixtures name the same
records without searching by a translated label.

The insert helper checks for an existing identifier before inserting. Re-running
the seed fills missing fixture records without replacing edits to existing ones.
This is different from a database reset: applying migrations and running this
seed does not drop user tables or delete user records.

The invoice fixture uses the same pure `ShopTotals` calculator as the application,
including mixed tax rates and ordered voucher applications. Seeded history need
not satisfy a user-interface preference for future delivery dates.

## Test the intended repeat behavior

The shop's `test/shop_migration_test.dart` starts from the earlier schema, inserts
legacy records, runs additive migrations and seeds twice. It asserts that schema
changes exist, legacy values survive and repeated seeding preserves edits.
`test/shop_api_test.dart` uses an isolated in-memory database, so its reset does
not affect the demonstration's `beak.db`.

For another application's seeder, choose explicitly whether existing rows are
preserved, updated or rejected. A stable ID alone does not make unconditional
inserts repeat-safe. Keep destructive reset commands separate from the normal
migrate-and-seed workflow.

## Continue reading

- [Migrations](migrations.md).
- [Testing](../shipping/testing.md).
