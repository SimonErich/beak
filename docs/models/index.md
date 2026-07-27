---
title: Schema
description: How a Beak resource is declared in one annotated class, and what beak prepare derives from it.
---

# Schema

A resource is one class. Its fields are its columns and its relationships, and
everything else follows from them: the table, the list page, the form, the
detail page, the REST validation and the CSV export. This section covers how to
write that class and every knob it exposes.

## What a schema class is

A schema class is a description, never an instance. You write the fields you
care about, annotate what the type cannot say, and `beak prepare` derives the
rest.

```dart title="examples/store/lib/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A shelf of the catalog.
///
/// The `products` side of the relationship is not declared here: `@BelongsTo`
/// on [Product.category] generates it, so the pair cannot drift apart.
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

Three facts drive everything below:

- **The type picks the column kind.** `String` is single-line text, `BeakText`
  is multi-line, `DateTime` is an instant, an enum is an enum column with its
  values.
- **Nullability picks required-ness.** `String name` is required and
  `BeakText? blurb` is not, and that one fact reaches the form validator, the
  API's validation and the column's `NOT NULL` together.
- **`@Column` carries what the type cannot.** Whether it sorts, whether search
  includes it, what the migration indexes, which rules run on input.

## What Beak derives from it

`beak prepare` writes `category.beak.dart` beside that file: the typed column
constants, the relationship constants (both sides), the `BeakModel`, and a
typed record view. It writes the table's migration once, and registers nothing,
because a file under `lib/models/` is a resource.

```dart title="examples/store/lib/models/category.beak.dart"
/// Typed column constants of the categories resource.
abstract final class CategoryColumns {
  /// Primary key.
  static const BeakStringColumn id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// What the category is called.
  static const BeakStringColumn name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired(), BeakMaxLength(120)],
    searchable: true,
    sortable: true,
  );
  // ...
}
```

Those names are what the rest of your app points at: `CategoryColumns.name` in
a filter or a chart mapper, `CategoryRelations.products` in a relation block,
`const CategoryModel()` in a test. You never write the constants, and you never
write a string field reference either.

!!! note "The one-definition promise"
    A column is declared once and then feeds six mouths: the table cell, the
    form field, the detail row, the filter control, the REST validator, and the
    CSV export column. You never touch `dynamic`. See
    [The one-definition promise](../concepts/the-one-definition-promise.md) for
    the why.

## Where each decision lives

| Decision | Where it goes |
| --- | --- |
| Columns, relationships, table name, soft deletes, timestamps | the `@Resource` class in `lib/models/<name>.dart` |
| Panel title, API origin, server port | `beak.yaml` |
| A resource's icon, label, section, or hiding it | `beak.yaml` under `resources.<table>` |
| A resource's filters, actions, view modes, detail layout, form steps | `lib/resources/<table>.dart`, in `BeakResource beakResource(BeakResource generated) => generated.copyWith(...)` |
| Theme, auth, the `/` screen, the server | `lib/theme.dart`, `lib/auth.dart`, `lib/dashboard.dart`, `lib/server.dart` |
| Everything else | generated into `lib/models/*.beak.dart` and `lib/beak/*.g.dart`, committed, never edited |

## In this section

| Page | What it covers |
| --- | --- |
| [Defining a resource](defining-models.md) | The `@Resource` class end to end, and what each annotation decides. |
| [Generated code](generated-code.md) | What `beak prepare` writes, where it goes, and what you commit. |
| [Column basics](column-basics.md) | The `@Column` options every kind shares: `visibleOn`, `sortable`, `searchable`, `filterable`, `indexed`, `unique`, `rules`. |
| [Column types](column-types.md) | All thirteen column kinds and the field type that picks each one. |
| [Validation rules](validation-rules.md) | The eleven rules a field carries, ten of them listed in `rules:`, enforced in the form and in the API. |
| [Relationships](relationships.md) | The four relationship kinds, and the keys, pivots and inverses Beak derives. |
| [Files and storage columns](files-and-storage-columns.md) | `@Image` and `@FileField`, upload rules, transforms, and where the bytes land. |
| [Escape hatches](escape-hatches.md) | Taking over from the generator, from one resource to the whole panel. |
| [The model registry](the-registry.md) | The generated index both the server and the panel resolve tables through. |

## Continue reading

- [Defining a resource](defining-models.md) writes your first schema class from
  scratch.
- [Generated code](generated-code.md) reads the part file it produces.
- [The one-definition promise](../concepts/the-one-definition-promise.md) is the
  idea this whole section is built on.
