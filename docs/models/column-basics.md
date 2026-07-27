---
title: Column basics
description: The configuration every Beak column shares, and how visibleOn and render intents make one definition render on every surface.
---

# Column basics

Every column type in Beak, from a plain string to an image with a transform
pipeline, shares the same base configuration. After this page you know what
those shared options do and how one column definition renders differently in a
table, a form, a detail view, and a filter.

## The shared config

`BeakColumn` is a sealed base class. You never construct it directly, you pick a
leaf like `BeakStringColumn` or `BeakEnumColumn`, but every leaf forwards these
same constructor parameters:

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
  this.rules = const [],
});
```

Here is what each one is for:

| Parameter | Type | Default | What it does |
| --- | --- | --- | --- |
| `key` | `String` | required | The storage/DB column name, snake_case. Beak wires it internally; you reference the column constant, never this string. |
| `label` | `String` | required | The human-readable label shown in tables, forms, and detail views. |
| `visibleOn` | `Set<BeakContext>` | table, form, detail | The surfaces the column appears on. |
| `sortable` | `bool` | `false` | Whether table views may sort by the column. |
| `searchable` | `bool` | `false` | Whether global search includes the column. |
| `filterable` | `bool` | `false` | Whether table views may filter by the column. |
| `rules` | `List<BeakRule>` | `const []` | Validation rules enforced on input, in order, on client and server. |

Notice `key` is the only string you write, and even that never appears in your
app code again: everywhere else you pass the column constant itself.
[Validation rules](validation-rules.md) covers the `rules` list in full.

## visibleOn: which surfaces a column appears on

`visibleOn` is a set of `BeakContext` values. There are four contexts, one per
render site:

```dart title="packages/beak_core/lib/src/context/beak_context.dart"
enum BeakContext {
  /// A cell inside a resource list/table.
  table,

  /// An editable input inside a create/edit form.
  form,

  /// A read-only entry inside a record detail view.
  detail,

  /// A filter control inside a table's filter bar.
  filter,
}
```

The default is `{table, form, detail}`: shown everywhere a value is edited or
read, but not offered as a filter. Narrow the set to hide a column from a
surface. A primary key, for instance, is read-only detail only:

```dart
/// Primary key.
static const id = BeakStringColumn(
  key: 'id',
  label: 'Id',
  visibleOn: {BeakContext.detail},
);

/// Last-update timestamp, rendered relatively in tables.
static const updatedAt = BeakDateTimeColumn(
  key: 'updated_at',
  label: 'Updated',
  format: BeakDateFormat.relative,
  sortable: true,
  visibleOn: {BeakContext.table, BeakContext.detail},
);
```

The `id` column shows up only on the detail view; `updatedAt` appears in the
table and detail but never in a form (the backend stamps it, so there is nothing
to edit).

!!! tip "filter is opt-in, not automatic"
    `filterable: true` marks a column as a candidate for filtering, but `filter`
    is not in the default `visibleOn` set. The panel builds filter controls from
    the [filters](../panel/tables-and-filters.md) you declare on a resource, not
    from `visibleOn` alone.

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

You never set intents yourself for the built-in columns; each type ships the
right config. The [custom column](column-types.md#the-escape-hatch) is the one
place you reach for the `custom` intent and register your own renderer. For the
full story of how intents become widgets, see
[Rendering per surface](../concepts/rendering-per-surface.md).

## Continue reading

- [Column types](column-types.md) every built-in column and the config it adds
  on top of these basics.
- [Validation rules](validation-rules.md) the rules you attach to `rules`.
- [Rendering per surface](../concepts/rendering-per-surface.md) how a render
  intent becomes an obers_ui widget.
