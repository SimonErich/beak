---
title: Schema builder
description: Every column type, modifier, index, and foreign key the Blueprint DSL supports, and how each maps to SQL and MongoDB.
---

This page is the complete reference for declaring schema inside migrations. It builds on [migrations](./migrations.md), which covers the run/rollback lifecycle around this DSL.

## The Schema facade

Your `upSchema` and `downSchema` overrides receive a `Schema` object with three operations:

```dart
await schema.create('users', (table) { /* declare columns */ });
await schema.alter('users', (table) { /* add or drop columns */ });
await schema.drop('users', ifExists: true);
```

You never construct a `Schema` yourself; the migration runner injects it. Its `adapter` getter exposes the wrapped `DatabaseAdapter` as an escape hatch for raw operations.

`create` and `alter` build a `Blueprint` and convert it into a backend-agnostic `SchemaDescriptor`; `drop` maps directly to a drop descriptor. All three reach the adapter through `DatabaseAdapter.executeSchema`. What survives that conversion is covered in [what reaches your database](#what-reaches-your-database) below; read it before relying on indexes or foreign keys declared here.

## Primary keys

Two canonical helpers, each with a spec alias:

```dart
table.idUuid();        // UUID PRIMARY KEY named "id"
table.idIncrements();  // auto-incrementing INTEGER PRIMARY KEY named "id"
table.id();            // alias for idUuid()
table.intId();         // alias for idIncrements()
```

All four accept an optional name: `table.idUuid(name: 'user_id')`. `idIncrements` marks the column both `primary` and `autoIncrementing`, which renders as `GENERATED ALWAYS AS IDENTITY` in the PostgreSQL dialect. The `PrimaryKeyType` enum (`uuid`, `integer`) is the model layer's mirror of this choice; see [defining models](../models/defining-models.md).

## Column types

`ColumnType` has 27 values. Each has a `BlueprintTable` method, and `TypeMapper` defines the canonical PostgreSQL and MongoDB BSON mapping for each. Driver compilers start from these canonical names and adjust for their own dialect where needed.

| `ColumnType` | Blueprint method | PostgreSQL type | BSON type |
| --- | --- | --- | --- |
| `string` | `string(name, {length = 255})` | `VARCHAR(length)` | `string` |
| `smallInteger` | `smallInteger(name)` | `SMALLINT` | `int` |
| `integer` | `integer(name)` | `INTEGER` | `int` |
| `bigInteger` | `bigInteger(name)` | `BIGINT` | `long` |
| `decimal` | `decimal(name, {precision = 10, scale = 2})` | `NUMERIC(precision,scale)` | `decimal` |
| `boolean` | `boolean(name)` | `BOOLEAN` | `bool` |
| `date` | `date(name)` | `DATE` | `date` |
| `dateTime` | `dateTime(name)` | `TIMESTAMPTZ` | `date` |
| `uuid` | `uuid(name)` | `UUID` | `string` |
| `json` | `json(name)` | `JSON` | `object` |
| `jsonb` | `jsonb(name)` | `JSONB` | `object` |
| `text` | `text(name)` | `TEXT` | `string` |
| `binary` | `binary(name)` | `BYTEA` | `binData` |
| `doublePrecision` | `doublePrecision(name)` | `DOUBLE PRECISION` | `double` |
| `enumType` | `enumColumn(name, values)` | `TEXT` | `string` |
| `tsvector` | `tsvector(name)` | `TSVECTOR` | `string` |
| `time` | `time(name)` | `TIME` | `date` |
| `interval` | `interval(name)` | `INTERVAL` | `date` |
| `inet` | `inet(name)` | `INET` | `string` |
| `macaddr` | `macaddr(name)` | `MACADDR` | `string` |
| `point` | `point(name)` | `POINT` | `object` |
| `line` | `line(name)` | `LINE` | `object` |
| `box` | `box(name)` | `BOX` | `object` |
| `money` | `money(name)` | `MONEY` | `decimal` |
| `bit` | `bit(name, {length = 1})` | `BIT(length)` | `string` |
| `xml` | `xml(name)` | `XML` | `string` |
| `array` | `array(name, elementType)` | `<element type>[]` | `array` |

Notes on the less obvious rows:

- `enumColumn('role', ['admin', 'user'])` records the allowed values on the `ColumnDefinition`, but the SQL rendering is plain `TEXT` with no `CHECK` constraint. Enforce the value set in your model layer via [validation](../models/validation.md).
- `array('tags', ColumnType.text)` renders as `TEXT[]`. The element type is required.
- `TypeMapper.toSqlType(type, {length, precision, scale, elementType})` and `TypeMapper.toMongoType(type)` are static and public, so you can reuse the mappings in your own tooling.

## Column modifiers

Every column method returns a `ColumnDefinition`. Modifiers mutate it in place; chain them with Dart cascades:

```dart
table.string('email')..makeNullable()..makeUnique();
table.integer('score')..withDefault(0);
table.uuid('tenant_id')..primary();
```

| Modifier | Effect in the PostgreSQL rendering |
| --- | --- |
| `..makeNullable()` | Removes the default `NOT NULL` |
| `..primary()` | `PRIMARY KEY` |
| `..makeUnique()` | `UNIQUE` |
| `..autoIncrementing()` | `GENERATED ALWAYS AS IDENTITY` |
| `..withDefault(value)` | `DEFAULT ...` (bools render `TRUE`/`FALSE`, numbers render bare, everything else is quoted) |
| `..withComment(text)` | Recorded on the definition; not rendered in DDL yet |
| `..generated(expression)` | Recorded on the definition; not rendered in DDL yet |

Defaults to remember: columns are NOT NULL unless you call `..makeNullable()`; `string` defaults to length 255; `decimal` defaults to precision 10, scale 2; `bit` defaults to length 1.

A single modifier also works without a cascade (`table.string('email').makeUnique()`), because the column registers itself the moment the column method runs. Use cascades as soon as you chain two or more.

## Convenience columns

```dart
table.timestamps();   // nullable dateTime created_at + updated_at
table.softDeletes();  // nullable dateTime deleted_at
```

Both emit nullable `dateTime` columns. `softDeletes()` pairs with the `SoftDeletes` model mixin; see [soft deletes](../models/soft-deletes.md).

## Indexes

```dart
table.index(['email']);                                  // users_email_idx
table.index(['a', 'b'], name: 'my_idx');                 // explicit name
table.index(['email'], unique: true);                    // unique index
table.unique(['email']);                                 // same thing, shorter
table.index(['payload'], kind: IndexKind.gin);           // index kind
table.index(['email'], where: 'email IS NOT NULL');      // partial index
```

- When you omit `name`, the index is auto-named `<table>_<columns joined by _>_idx`.
- `IndexKind` offers `btree` (the default), `gin`, `gist`, and `hash`.
- `where` becomes a `WHERE` clause on the rendered `CREATE INDEX`, giving you partial indexes on backends that support them.
- The PostgreSQL rendering is `CREATE [UNIQUE ]INDEX "name" ON "table" USING <kind> (cols)[ WHERE ...];`.

For cross-adapter index creation at runtime, worm also ships `SchemaIndexDescriptor(collection:, field:, unique:)`, a `SchemaDescriptor` subtype with `SchemaOperation.createIndex` that adapters execute directly (SQL adapters compile it; the MongoDB adapter calls `createIndex`; the in-memory adapter treats it as a no-op).

## Foreign keys

Single-column:

```dart
table.foreign(
  column: 'user_id',
  references: 'id',
  onTable: 'users',
  onDelete: OnDelete.cascade,
);
```

Composite (multi-column), where local and referenced columns match by index and the lists must have equal length:

```dart
table.foreignComposite(
  columns: ['org_id', 'team_id'],
  referencedColumns: ['org_id', 'id'],
  onTable: 'teams',
  onDelete: OnDelete.restrict,
);
```

Both accept an optional `name` for the constraint. `onDelete` defaults to `OnDelete.restrict`. The six actions and their SQL rendering:

| `OnDelete` | SQL rendering | Behavior |
| --- | --- | --- |
| `cascade` | `CASCADE` | Database engine deletes children silently; no model hooks fire |
| `ormCascade` | `NO ACTION` | Worm deletes children at runtime, firing `beforeDelete`/`afterDelete` on each |
| `restrict` | `RESTRICT` | Delete fails while children exist |
| `setNull` | `SET NULL` | Child FK column set to NULL |
| `setDefault` | `SET DEFAULT` | Child FK column set to its default |
| `noAction` | `NO ACTION` | Database default behavior |

:::note[ormCascade is not a database cascade]
`OnDelete.ormCascade` deliberately renders `NO ACTION` in SQL. The ORM walks every dependent row before issuing the parent delete, so observers, soft-delete scopes, and casts all run. See [working with relations](../relations/working-with-relations.md) for the runtime walk.
:::

## Altering and dropping

Inside `schema.alter`, column methods mean `ADD COLUMN`, and `dropColumn` marks a column for removal:

```dart
await schema.alter('users', (table) {
  table.string('bio').makeNullable();  // ADD COLUMN
  table.dropColumn('legacy_flag');     // DROP COLUMN
});
```

`schema.drop('users')` drops the table; pass `ifExists: true` to make it idempotent.

:::caution[alter support is limited today]
Read the next section before using `schema.alter`. As of this writing, every shipped adapter rejects the alter descriptor at execution time.
:::

## What reaches your database

The `Schema` facade converts each `Blueprint` into a `SchemaDescriptor` before the adapter sees it, and that conversion keeps only five properties per column: `name`, `type`, `nullable`, `isPrimaryKey`, and `defaultValue`. Everything else you declared lives only on the `Blueprint`:

- Indexes, `unique(...)`, and single-column `..makeUnique()` constraints
- Foreign keys (single and composite)
- `..autoIncrementing()`, `length`, `precision`, `scale`
- `..withComment(...)` and `..generated(...)`
- `dropColumn(...)` marks (the descriptor has no dropped-columns field)

Full fidelity exists only in the direct renderings: `Blueprint.toSql()` produces complete PostgreSQL DDL (columns, constraints, foreign keys, and index statements), and `Blueprint.toMongo()` produces a MongoDB description document. If you need the parts the facade drops, render the blueprint yourself and execute it through the adapter's raw surface:

```dart
final blueprint = Blueprint.create('users', (table) {
  table.idUuid();
  table.string('email').makeUnique();
  table.uuid('team_id');
  table.foreign(
    column: 'team_id',
    references: 'id',
    onTable: 'teams',
    onDelete: OnDelete.cascade,
  );
});
await schema.adapter.rawExecute(blueprint.toSql(), const []);
```

One wrinkle: when a blueprint declares indexes, `toSql()` appends each `CREATE INDEX` as a separate statement after the `CREATE TABLE`. Drivers that reject multi-statement strings need each statement executed individually, so split the output on statement boundaries or keep index creation in its own blueprint.

`SchemaOperation.alter` support also varies by adapter, and today it is uniformly absent: the in-memory adapter throws `UnsupportedOperationException`, the PostgreSQL, MySQL, and SQLite compilers throw `QueryException` (`compileDdl(SchemaOperation.alter) is not implemented`), and the MongoDB adapter throws `QueryException` because collections are schemaless. Until that lands, express alters as raw DDL via `Blueprint.alter(...).toSql()` plus `rawExecute`, and keep `schema.alter` calls out of migrations you intend to run.

## Gotchas

- Columns are NOT NULL by default. Forgetting `..makeNullable()` is the most common migration bug.
- `schema.alter` currently fails at execution time on every shipped adapter. Use `Blueprint.alter(...).toSql()` with `rawExecute` for now.
- Indexes and foreign keys declared in a blueprint do not reach the adapter through `schema.create`. Render `Blueprint.toSql()` yourself when you need them applied.
- `dropColumn` marks are silently dropped by the facade conversion; they render only via `Blueprint.toSql()`.
- `enumColumn` renders plain `TEXT` with no `CHECK` constraint.
- `..withComment` and `..generated` are recorded but not rendered in DDL yet.
- Modifiers mutate the `ColumnDefinition` in place. With two or more modifiers, use cascades (`..`), not dot chains: `void`-returning modifiers do not return the column.
- `Blueprint.toSql()` renders `DROP TABLE IF EXISTS` unconditionally, while `schema.drop` defaults to `ifExists: false`. Pass `ifExists: true` explicitly in `downSchema`.
- `TypeMapper` speaks canonical PostgreSQL. Individual drivers may map types differently in their own compilers; check the [driver pages](../drivers/choosing-a-database.mdx) for dialect notes.

## API summary

### Types

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `Schema` | `create(table, build)`, `alter(table, build)`, `drop(table, {ifExists})`, `adapter` | Facade handed to `upSchema`/`downSchema`; translates blueprints to descriptors |
| `Blueprint` | `Blueprint.create(table, build)` / `.alter(table, build)` / `.drop(table)`; `toSql()`, `toMongo()` | One captured DDL operation with full-fidelity renderers |
| `BlueprintOperation` | `create`, `alter`, `drop` | Kind of operation a `Blueprint` captures |
| `BlueprintTable` | column methods, `index`, `unique`, `foreign`, `foreignComposite`, `dropColumn` | Fluent table builder inside `create`/`alter` callbacks |
| `ColumnDefinition` | mutable; `..makeNullable()`, `..primary()`, ... | One column plus its modifiers |
| `ColumnType` | 27-value enum | Abstract, backend-agnostic column types (full table above) |
| `IndexDefinition` | `{name, columns, unique, kind, partialWhere}`; `toMap()` | Index spec produced by `index()`/`unique()` |
| `IndexKind` | `btree`, `gin`, `gist`, `hash` | Index storage strategy; `btree` is the default |
| `ForeignKeyDefinition` | default ctor (single column) or `.composite(...)`; `toMap()` | FK constraint spec; `onDelete` defaults to `restrict` |
| `OnDelete` | `cascade`, `ormCascade`, `restrict`, `setNull`, `setDefault`, `noAction` | Referential delete action (rendering table above) |
| `PrimaryKeyType` | `uuid`, `integer` | PK generation strategy used by the model layer |
| `TypeMapper` | static `toSqlType(type, {length, precision, scale, elementType})`, `toMongoType(type)` | Canonical PostgreSQL / BSON names per abstract type |
| `TableSchema` | `{name, columns}`; `column(name)`, `toMap()` | Immutable table snapshot consumed by the diff engine |
| `ColumnSnapshot` | `{name, type, nullable, isPrimaryKey}`; `toMap()` | Immutable column snapshot inside a `TableSchema` |
| `SchemaIndexDescriptor` | `{collection, field, unique}` extends `SchemaDescriptor` | Cross-adapter index-creation descriptor (`SchemaOperation.createIndex`) |

### BlueprintTable methods

| Method | Signature sketch | One-liner |
| --- | --- | --- |
| `string` | `string(name, {int length = 255})` | `VARCHAR` column |
| `integer` | `integer(name)` | 32-bit integer column |
| `smallInteger` | `smallInteger(name)` | 16-bit integer column |
| `bigInteger` | `bigInteger(name)` | 64-bit integer column |
| `decimal` | `decimal(name, {precision = 10, scale = 2})` | Fixed-precision numeric column |
| `boolean` | `boolean(name)` | Boolean column |
| `date` | `date(name)` | Date-only column |
| `dateTime` | `dateTime(name)` | Timestamp-with-timezone column |
| `uuid` | `uuid(name)` | UUID column |
| `json` | `json(name)` | JSON (text storage) column |
| `jsonb` | `jsonb(name)` | JSON (binary storage) column |
| `text` | `text(name)` | Unlimited-length text column |
| `binary` | `binary(name)` | Raw binary column |
| `doublePrecision` | `doublePrecision(name)` | Double-precision float column |
| `enumColumn` | `enumColumn(name, List<String> values)` | Enum-valued column (renders `TEXT`) |
| `tsvector` | `tsvector(name)` | Full-text search vector column |
| `time` | `time(name)` | Time-of-day column |
| `interval` | `interval(name)` | Duration column |
| `inet` | `inet(name)` | IP address column |
| `macaddr` | `macaddr(name)` | MAC address column |
| `point` | `point(name)` | Geometric point column |
| `line` | `line(name)` | Geometric line column |
| `box` | `box(name)` | Geometric box column |
| `money` | `money(name)` | Monetary amount column |
| `bit` | `bit(name, {int length = 1})` | Fixed-length bit string column |
| `xml` | `xml(name)` | XML document column |
| `array` | `array(name, ColumnType elementType)` | Array column of another type |
| `timestamps` | `timestamps()` | Nullable `created_at` + `updated_at` |
| `softDeletes` | `softDeletes()` | Nullable `deleted_at` |
| `idUuid` | `idUuid({name = 'id'})` | UUID primary key |
| `idIncrements` | `idIncrements({name = 'id'})` | Auto-incrementing integer primary key |
| `id` | `id({name = 'id'})` | Alias for `idUuid` |
| `intId` | `intId({name = 'id'})` | Alias for `idIncrements` |
| `dropColumn` | `dropColumn(columnName)` | Mark a column for removal during ALTER |
| `index` | `index(columns, {name, unique = false, kind = btree, where})` | Add an index, auto-named when `name` omitted |
| `unique` | `unique(columns, {name})` | Add a unique index |
| `foreign` | `foreign({column, references, onTable, onDelete = restrict, name})` | Single-column FK constraint |
| `foreignComposite` | `foreignComposite({columns, referencedColumns, onTable, onDelete = restrict, name})` | Multi-column FK constraint |

### ColumnDefinition modifiers

| Modifier | Signature sketch | One-liner |
| --- | --- | --- |
| `makeNullable` | `void makeNullable()` | Allow NULL |
| `primary` | `void primary()` | Mark as primary key |
| `autoIncrementing` | `void autoIncrementing()` | Mark as auto-increment |
| `makeUnique` | `void makeUnique()` | Add a unique constraint |
| `withDefault` | `void withDefault(Object? value)` | Set the default value |
| `withComment` | `void withComment(String text)` | Record a comment (not rendered yet) |
| `generated` | `void generated(String expression)` | Record a generated-column expression (not rendered yet) |
| `toMap` | `Map<String, Object?> toMap()` | Serialize the definition |

## Continue reading

- [Migrations](./migrations.md): the lifecycle that runs these blueprints.
- [Migrations in depth](./migrations-in-depth.md): pretend mode, diffing, and auto-generated migrations built on this DSL.
- [Choosing a database](../drivers/choosing-a-database.mdx): per-driver dialect notes and capability differences.
- [Soft deletes](../models/soft-deletes.md): the model-side contract behind `softDeletes()`.
