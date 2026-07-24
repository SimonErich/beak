---
title: Defining models
description: Write a Beak resource with the columns/relations/model idiom and learn every BeakModel override.
---

# Defining models

After this page you can write a complete `BeakModel` from scratch: its columns,
its relationships, and the handful of getters that set its behavior. We build up
the reference store's products resource, the showcase model that touches every
major column kind.

## The three-part idiom

A Beak resource is three declarations that live side by side, usually in one file:

1. A `XxxColumns` class of `static const` columns.
2. A `XxxRelations` class of `static const` relationships.
3. A `XxxModel` that references both.

The reason for splitting them is reuse. Each column is a single typed constant, so
a filter, a form section, and a table can all point at
`ProductColumns.price` instead of retyping `'price'` and hoping the strings match.
The model just gathers them.

### Columns

Group a resource's columns as `static const` fields on an `abstract final class`.
That class is never instantiated: it is a namespace of reusable references.

```dart title="apps/reference_admin_models/lib/src/product.dart"
abstract final class ProductColumns {
  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  /// Sale price in euros.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    sortable: true,
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    name,
    description,
    price,
    stock,
    status,
    image,
    categoryId,
    createdAt,
    updatedAt,
  ];
}
```

The `values` list is the one the model hands to Beak, and its order is the order
columns appear in tables, forms, and detail views. See
[Column basics](column-basics.md) for the config every column shares and
[Column types](column-types.md) for the full menu.

### Relationships

Relationships get the same treatment: `static const` constants on their own
namespace class.

```dart title="apps/reference_admin_models/lib/src/product.dart"
abstract final class ProductRelations {
  /// The category a product is filed under.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
  );

  /// The tags attached to a product.
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'product_tag',
    foreignPivotKey: 'product_id',
    relatedPivotKey: 'tag_id',
    searchColumnKeys: ['name'],
  );
}
```

[Relationships](relationships.md) covers all four kinds and how each renders.

### The model

The model ties the two together. It extends `BeakModel` (an `abstract base
class`) with a `final class` and a `const` constructor, then overrides the
getters that describe the resource.

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

!!! note "What just happened"
    - You declared columns and relationships as reusable typed constants, then
      pointed a `const ProductModel()` at them.
    - `table` and `displayColumnKey` are the only two getters you must always
      set. `relationships`, `softDeletes`, and `primaryKey` have defaults.
    - Registering this one instance (next section) gives you a CRUD API and a
      table, detail, and form panel page. No endpoints, no widgets by hand.

## The BeakModel overrides

`BeakModel` exposes six getters. Two are required, the rest have sensible
defaults you override only when a resource needs it.

| Getter | Type | Required | Default | What it sets |
| --- | --- | --- | --- | --- |
| `table` | `String` | yes | n/a | The physical table or collection name backing the resource. |
| `displayColumnKey` | `String` | yes | n/a | The column that represents a record in pickers and relation links. |
| `columns` | `List<BeakColumn>` | yes | n/a | The columns, in display order. |
| `relationships` | `List<BeakRelationship>` | no | `const []` | The resource's relationships. |
| `softDeletes` | `bool` | no | `false` | Whether deletes set a marker the backend filters on instead of removing the row. |
| `primaryKey` | `BeakColumn` | no | first column keyed `'id'` | The primary-key column Beak reads a record's id from. |

### The primary key default

You rarely override `primaryKey`. By default it finds the column whose key is
`'id'` and throws a clear error if there is none:

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
/// The primary-key column: by default the first column with key `'id'`.
///
/// Throws a [BeakConfigurationException] when no such column exists and
/// the model does not override this getter with its actual key column.
BeakColumn get primaryKey {
  final column = columnByKey('id');
  if (column == null) {
    throw BeakConfigurationException(
      'Model "$table" has no column with key "id"; add one or override '
      'primaryKey.',
    );
  }
  return column;
}
```

If your table's key column is named something else (say `uuid`), add that column
to `columns` and override `primaryKey` to return it. Everything downstream,
including record links and delete calls, reads the id through this one getter.

## Helpers the base class gives you

`BeakModel` also carries a few read-only helpers so you never have to hunt
through `columns` yourself. They matter mostly to the framework, but they are
public and typed if you need them:

| Method | Returns |
| --- | --- |
| `columnsFor(BeakContext context)` | The columns whose `visibleOn` includes `context`, in order. |
| `columnByKey(String key)` | The first column with that key, or `null`. |
| `relationshipByKey(String key)` | The first relationship with that key, or `null`. |
| `primaryKeyOf(BeakRecord record)` | The record's id value, or `null` when it does not carry one. |

!!! question "What this skipped"
    - The column config (`key`, `label`, `visibleOn`, and friends) is in
      [Column basics](column-basics.md).
    - Turning a model into a live server and panel is
      [The model registry](the-registry.md).

## Continue reading

- [Column basics](column-basics.md) the config every column shares.
- [The model registry](the-registry.md) how registered models become a running
  API and panel.
- [Relationships](relationships.md) the four relationship kinds in full.
