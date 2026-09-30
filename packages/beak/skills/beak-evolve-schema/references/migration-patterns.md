# Migration patterns

All of these were run against SQLite (the default database) and a fresh
database. Every migration starts with `import 'package:beak/migrations.dart';`
and the schema file that holds the `<Name>Columns` constants, for example
`import '../resources/suppliers/models/supplier.dart';`. Table names in
`schema.alter` are the physical ones (`suppliers`); column keys come from the
generated constants (`SupplierColumns.code.key`).

Migrations run in `name` order, and the stamp in the name (`20260929_054551_...`)
is what orders them. `beak make:migration` writes it. The one exception is
`beak prepare` registering the migration that creates a table ahead of the first
migration whose tables point at it, so a fresh database never references a
table that is not there yet. An `alter` keeps its place after its create.

## Add columns (what `--from-drift` writes)

```dart
@override
Future<void> upSchema(Schema schema) async {
  final live = await schema.adapter.introspectSchema();
  if (!_has(live, 'suppliers', 'code')) {
    await schema.alter('suppliers', (table) {
      BeakBlueprint.defineColumn(table, SupplierColumns.code);
    });
  }
  if (!_has(live, 'suppliers', 'rating')) {
    await schema.alter('suppliers', (table) {
      BeakBlueprint.defineColumn(table, SupplierColumns.rating);
    });
  }
}

@override
Future<void> downSchema(Schema schema) async {
  final live = await schema.adapter.introspectSchema();
  if (_has(live, 'suppliers', 'code')) {
    await schema.alter('suppliers', (table) {
      table.dropColumn('code');
    });
  }
  // ... and the same for rating.
}

/// Whether [column] is already in [table] of the live schema.
static bool _has(Map<String, List<String>> live, String table, String column) =>
    live[table]?.contains(column) ?? false;
```

The guard is the point: a fresh database already has the column from the
create migration, so an unguarded `alter` fails there with a duplicate-column
error. `BeakBlueprint.defineColumn` derives the type, length, scale and default
from the field, so the alter and the create migration cannot become different
columns. Copy this shape into a migration you write by hand.

## Add a belongs-to relation

`--from-drift` writes the key column, its index and its constraint together,
the way a create migration does, read from the relationship constant:

```dart
await schema.alter('suppliers', (table) {
  BeakBlueprint.defineColumn(
    table,
    SupplierColumns.backupCompanyId,
    isForeignKey: true,
  );
  final relation = SupplierRelations.backupCompany;
  table.index([relation.foreignKey]);
  table.foreign(
    column: relation.foreignKey,
    references: 'id',
    onTable: relation.relatedTable,
    onDelete: wormOnDelete(relation.onDelete),
  );
});
```

Declared in the same `alter` as its column, the reference is additive on
SQLite too. Its `downSchema` drops the index first
(`table.dropIndex('suppliers_backup_company_id_idx')`) and then the column,
because SQLite refuses to drop an indexed column. A new many-to-many needs no
migration of yours: `beak prepare` writes `create_<pivot table>_table.dart`,
which calls `BeakBlueprint.createPivot(schema, XRelations.tags, ownerTable:
'products')`, and `beak migrate` applies it.

## Required column on a table with rows

Give the schema field `@Column(defaultValue: ...)` and `--from-drift` handles
it. Without a default, in two migrations of your own:

```dart
// 1. add nullable and backfill
await schema.alter('products', (table) {
  table.string('sku', length: 40).makeNullable();
});
await schema.adapter.rawExecute(
  "UPDATE products SET sku = 'P-' || id WHERE sku IS NULL",
  const [],
);
```

Guard the alter with the `introspectSchema()` check as above. Then let the
schema class declare the field required: the API enforces it, and the column
stays nullable. Tightening the column itself, `table.string('sku', length: 40)
.change()`, works on Postgres and throws `UnsupportedOperationException` on
SQLite, which cannot alter an existing column; there the choice is a table
rebuild with `rawExecute`, or leaving the column nullable.

Add uniqueness after the backfill, in its own migration:

```dart
await schema.alter('products', (table) {
  table.unique(['sku']);
});
```

## Drop a column

```dart
final live = await schema.adapter.introspectSchema();
if (!(live['products']?.contains('legacy_code') ?? false)) {
  return;
}
await schema.alter('products', (table) {
  table.dropColumn('legacy_code');
});
```

The check matters: a fresh database never had the column, because the create
migration reads a model that no longer declares it. Postgres drops a column's
indexes and unique constraint together with it. SQLite does not: an index on
the column makes the drop fail with "error in index ... after drop column", so
drop the index in the same `alter`, before the column:
`table.dropIndex('products_sku_idx');`. An index added with
`table.unique([...])` is named `<table>_<columns>_idx`; use the name the
database reports. A column made with `unique: true` has a constraint in the
table definition instead of an index. SQLite cannot drop such a column with
`dropColumn`, and `dropIndex` on the constraint name (`<table>_<column>_key`)
fails on both databases, so on SQLite rebuild the table with `rawExecute`
(create the new table, `INSERT ... SELECT`, drop the old one, rename it) or keep
the column. Dropping loses data, so make `downSchema` throw:

```dart
@override
Future<void> downSchema(Schema schema) async =>
    throw IrreversibleMigrationException(
      migration: name,
      message: 'Dropping legacy_code cannot be undone.',
    );
```

## Rename a column

Keep the column and rename only the Dart field with
`@Column(columnName: 'old_name')`. To change the column itself: add the new
column (guarded), copy with
`rawExecute('UPDATE products SET new_name = old_name', const [])`, ship, and drop
the old column in a later migration once nothing reads it.

## Retype a column

Postgres: `table.string('code', length: 80).change();` (the definition is the
complete end state, not a delta). SQLite: add a new column, copy, drop the old
one in a later migration.
