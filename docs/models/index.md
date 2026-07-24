---
title: Models and data
description: How a Beak resource is defined: the model, its columns, its relationships, and the registry that ties them together.
---

# Models and data

A Beak model is the one definition that drives everything else: the table, the
form, the detail view, the filters, the REST validation, and the CSV export.
You write it once, register it, and both the Shelf server and the Flutter panel
read from the same source. This section covers how to write that definition and
every knob it exposes.

## What a model is

A model is plain metadata. It names a table, lists that table's columns, declares
its relationships, and sets its delete semantics. It never runs a query itself:
the backend pairs it with a `BeakDataSource` (worm today, another ORM tomorrow),
and that seam is what lets one definition drive both sides.

Here is the whole shape, from the reference store's products resource:

```dart title="apps/reference_admin_models/lib/src/product.dart"
final class ProductModel extends BeakModel {
  /// Creates the products model.
  const ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProductColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductRelations.category,
    ProductRelations.tags,
  ];

  @override
  bool get softDeletes => true;
}
```

That is the entire contract. The interesting work lives in `ProductColumns` and
`ProductRelations`, which is where the next few pages go.

!!! note "The one-definition promise"
    A `BeakColumn` is declared once and then feeds six mouths: the table cell,
    the form field, the detail row, the filter control, the REST validator, and
    the CSV export column. You never write a string field reference and you
    never touch `dynamic`. See
    [The one-definition promise](../concepts/the-one-definition-promise.md) for
    the why.

## In this section

| Page | What it covers |
| --- | --- |
| [Defining models](defining-models.md) | The `XxxColumns` / `XxxRelations` / `XxxModel` idiom and every `BeakModel` override. |
| [Column basics](column-basics.md) | The config every column shares: `key`, `label`, `visibleOn`, `sortable`, `searchable`, `filterable`, `rules`. |
| [Column types](column-types.md) | A tour of all thirteen built-in column types with a real snippet for each. |
| [Validation rules](validation-rules.md) | The rules you attach to a column's `rules` list, enforced on both client and server. |
| [Relationships](relationships.md) | `belongsTo`, `hasOne`, `hasMany`, and `belongsToMany`, and how each renders. |
| [The model registry](the-registry.md) | How models are registered so the backend and panel can resolve them by table. |
| [Files and storage columns](files-and-storage-columns.md) | Image and file columns, upload rules, and the storage drivers behind them. |

## Continue reading

- [Defining models](defining-models.md) writes your first model from scratch.
- [The one-definition promise](../concepts/the-one-definition-promise.md) is the
  idea this whole section is built on.
