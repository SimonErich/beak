# Migration patterns

All of these were run against SQLite (the default database) and a fresh
database. Every migration starts with `import 'package:beak/migrations.dart';`
and the schema file that holds the `<Name>Columns` constants, for example
`import '../resources/suppliers/models/supplier.dart';`. Table names in
`schema.alter` are the physical ones (`suppliers`); column keys come from the
generated constants (`SupplierColumns.code.key`).

Migrations run in `name` order, and the stamp in the name (`20260929_054551_...`)
is what orders them. `beak make:migration` writes it.

## Add columns (what `--from-drift` writes, made safe)

```dart
@override
Future<void> upSchema(Schema schema) async {
  final live = await schema.adapter.introspectSchema();
  final missing = [
    for (final column in [SupplierColumns.code, SupplierColumns.rating])
      if (!(live['suppliers']?.contains(column.key) ?? false)) column,
  ];
  if (missing.isEmpty) {
    return;
  }
  await schema.alter('suppliers', (table) {
    for (final column in missing) {
      BeakBlueprint.defineColumn(table, column);
    }
  });
}

@override
Future<void> downSchema(Schema schema) async {
  await schema.alter('suppliers', (table) {
    table.dropColumn('code');
    table.dropColumn('rating');
  });
}
```

`BeakBlueprint.defineColumn` derives the type, length, scale and default from
the field, so the alter and the create migration cannot become different
columns.

## Add a belongs-to relation

`--from-drift` writes the foreign-key column as a plain column. Replace its
body so the constraint matches what a fresh database gets:

```dart
final live = await schema.adapter.introspectSchema();
if (live['suppliers']?.contains(SupplierColumns.backupCompanyId.key) ?? false) {
  return;
}
await schema.alter('suppliers', (table) {
  BeakBlueprint.defineColumn(
    table,
    SupplierColumns.backupCompanyId,
    isForeignKey: true,
  );
  table.index([SupplierColumns.backupCompanyId.key]);
  table.foreign(
    column: SupplierColumns.backupCompanyId.key,
    references: 'id',
    onTable: 'companies',
    onDelete: OnDelete.setNull,
  );
});
```

Declared in the same `alter` as its column, the reference is additive on
SQLite too. A many-to-many needs a pivot table: `BeakBlueprint.createPivot(
schema, XRelations.tags, ownerTable: 'products')`, guarded by the same
`introspectSchema()` check on the pivot name.

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
migration reads a model that no longer declares it. A column that is indexed or
unique cannot be dropped while its index exists (SQLite fails with "error in
index ... after drop column"), so drop the index in the same `alter`, before
the column: `table.dropIndex('products_sku_idx');`. Use the name the database
reports; a `unique: true` column made at creation is `<table>_<column>_key`, an
index added with `table.unique([...])` is `<table>_<columns>_idx`. Dropping
loses data, so make `downSchema` throw:

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
