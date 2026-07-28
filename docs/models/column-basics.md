---
title: Column basics
description: What @Column carries on every field, how visibleOn picks the surfaces, and how one field renders in a table, a form, a detail view and a filter.
---

# Column basics

Every column in Beak, from a plain string to an image with a transform
pipeline, shares one set of options. After this page you know what each of them
does, which ones the migration reads, and how one field renders differently in
a table, a form, a detail view and a filter.

## The shared config

The field's Dart type picks the column kind. `@Column` carries the rest, and
these parameters mean the same thing whatever the kind is:

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `columnName` | `String?` | the snake-cased field name | The storage column name. |
| `label` | `String?` | the title-cased field name | The human label shown in tables, forms and detail views. |
| `visibleOn` | `Set<BeakContext>?` | table, form, detail | The surfaces the column appears on. |
| `sortable` | `bool` | `false` | Table views may order by it. |
| `searchable` | `bool` | `false` | Search includes it. |
| `filterable` | `bool` | `false` | The list page derives a filter control from it. |
| `indexed` | `bool` | `false` | The generated migration indexes it. |
| `unique` | `bool` | `false` | The generated migration adds a unique index. |
| `rules` | `List<BeakRule>` | `const []` | Validation rules, run in order, in the form and again in the API. |

Everything else `@Column` takes belongs to one kind (`prefix` on a number,
`format` on a `DateTime`, `trueLabel` on a `bool`).
[Column types](column-types.md) takes those one at a time, and
[Annotations](../reference/annotations.md) lists them in one table.

Here is a field carrying four of the shared options:

```dart title="examples/store/lib/models/tag.dart"
/// What the tag is called.
@Display()
@Column(
  searchable: true,
  sortable: true,
  unique: true,
  rules: [BeakMaxLength(60)],
)
late final String name;
```

and the constant `beak prepare` writes from it:

```dart title="examples/store/lib/models/tag.beak.dart"
/// What the tag is called.
static const BeakStringColumn name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  rules: [BeakRequired(), BeakMaxLength(60)],
  searchable: true,
  sortable: true,
  unique: true,
);
```

Two things arrived without being written. `key` and `label` come from the field
name, and `BeakRequired()` comes from the field not being nullable. From here on
your app points at `TagColumns.name`, the constant, never at `'name'`, the
string.

The constant is an instance of the sealed `BeakColumn` base, whose constructor
is the shared config in code:

```dart title="packages/beak_core/lib/src/columns/beak_column.dart"
const BeakColumn({
  required this.key,
  required this.label,
  this.visibleOn = const {
    BeakContext.table,
    BeakContext.form,
    BeakContext.detail,
  },
  this.sortable = false,
  this.searchable = false,
  this.filterable = false,
  this.indexed = false,
  this.unique = false,
  this.rules = const [],
});
```

[Validation rules](validation-rules.md) covers the `rules` list in full.

## visibleOn: which surfaces a column appears on

`visibleOn` is a set of `BeakContext` values. There are four contexts, one per
render site:

```dart title="packages/beak_core/lib/src/context/beak_context.dart"
--8<-- "packages/beak_core/lib/src/context/beak_context.dart:BeakContext"
```

The default is `{table, form, detail}`: shown everywhere a value is edited or
read. Narrow the set to keep a field off a surface. A long blurb, for instance,
belongs in the form and the detail view but would crowd a table row:

```dart title="examples/store/lib/models/category.dart"
/// The one-line blurb shown above the product list.
@Column(visibleOn: {BeakContext.form, BeakContext.detail})
late final BeakText? blurb;
```

The columns Beak adds for you come pre-narrowed. The primary key is detail only,
and the timestamps are never editable, because the API stamps them:

```dart title="examples/store/lib/models/product.beak.dart"
/// Primary key.
static const BeakStringColumn id = BeakStringColumn(
  key: 'id',
  label: 'Id',
  visibleOn: {BeakContext.detail},
);

// ... the columns declared on the schema class ...

/// When the record was last updated.
static const BeakDateTimeColumn updatedAt = BeakDateTimeColumn(
  key: 'updated_at',
  label: 'Updated',
  sortable: true,
  format: BeakDateFormat.relative,
  visibleOn: {BeakContext.table, BeakContext.detail},
);
```

## Sorting, searching and filtering

Three flags, three surfaces of the list page:

- **`sortable: true`** gives the column a sortable table header, and lets a
  query spec order by it.
- **`searchable: true`** puts the column in the set the search box queries.
  Search with no searchable column finds nothing, so mark at least the name.
- **`filterable: true`** contributes a filter control to the filter bar.

The filter bar is derived. A resource that declares no filters of its own gets
one control per filterable column, of the kind that column's type calls for:

```dart title="packages/beak_frontend/lib/src/filters/beak_default_filters.dart"
--8<-- "packages/beak_frontend/lib/src/filters/beak_default_filters.dart:beakDefaultFiltersOf"
```

Enums become a select, booleans a switch, strings and text a contains-search,
dates a range. A filterable number has no obvious control yet and is skipped
rather than guessed at: declare that one on the resource. See
[Tables and filters](../panel/tables-and-filters.md) for the declared kind.

!!! tip "filterable is a flag, filter is a context"
    `filterable: true` is what creates the control. `BeakContext.filter` is
    where a control asks the column how to draw itself, which is why `filter`
    is not in the default `visibleOn` set and does not need to be.

## Indexing and uniqueness

`indexed` and `unique` are read by the generated migration, not by the panel.
`unique` writes a unique index, so it indexes too; declaring both is the same
fact twice. Every belongs-to foreign key is indexed without being asked, since
the panel joins on them to draw a list page, so these two are for the columns
you sort or filter by often.

```dart title="examples/store/lib/models/product.dart"
/// The stock-keeping unit, unique across the catalog.
@Column(
  label: 'SKU',
  searchable: true,
  unique: true,
  rules: [BeakMaxLength(40)],
)
late final String sku;
```

!!! warning "Adding an index to a table that exists"
    `beak prepare` writes a table's migration once and never rewrites it. Adding
    `indexed: true` to a resource that has already migrated changes the model,
    not the database: write a migration that alters the table with
    `schema.alter`. See [Migrations](../backend/migrations.md).

## Render intents: one column, four surfaces

A column does not know what a table cell or a form field looks like. `beak_core`
never imports Flutter. Instead each column declares a `BeakRenderConfig`: a
render *intent* per context, and `beak_frontend` maps each intent to an obers_ui
widget. This is the pivot that lets one definition render everywhere.

The base class exposes the intent lookup:

```dart title="packages/beak_core/lib/src/columns/beak_column.dart"
/// The per-context render configuration of this column.
BeakRenderConfig get renderConfig;

/// Returns the rendering hint this column resolves to in [context] (the
/// frontend maps each [BeakRenderIntent] to an obers_ui widget). A
/// convenience shortcut for `renderConfig.intentFor(context)`.
BeakRenderIntent intentFor(BeakContext context) =>
    renderConfig.intentFor(context);
```

Most columns render the same way on every surface, so their config is built with
`BeakRenderConfig.uniform`. A `BeakStringColumn`, for example, is
`BeakRenderConfig.uniform(BeakRenderIntent.text)`: plain text in the table, the
form, the detail, and the filter alike.

Some columns differ by surface. A `BeakDateTimeColumn` set to
`BeakDateFormat.relative` shows "3 days ago" in a table but an absolute date
picker in a form:

```dart title="packages/beak_core/lib/src/columns/beak_date_time_column.dart"
@override
BeakRenderConfig get renderConfig => BeakRenderConfig(
  table: _displayIntent,
  form: BeakRenderIntent.date,
  detail: _displayIntent,
  filter: BeakRenderIntent.date,
);
```

You never set intents. Each kind ships the right config, and a field annotated
`@Custom` is the one place you name a renderer of your own (see
[the escape hatch](column-types.md#the-escape-hatch)). For the full story of how
intents become widgets, see
[Rendering per surface](../concepts/rendering-per-surface.md).

## Continue reading

- [Column types](column-types.md) every column kind and the field type that
  picks it.
- [Validation rules](validation-rules.md) the rules you list in `rules:`.
- [Annotations](../reference/annotations.md) every parameter of `@Column`, in
  one table.
- [Rendering per surface](../concepts/rendering-per-surface.md) how a render
  intent becomes an obers_ui widget.
