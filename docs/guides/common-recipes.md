---
title: Common recipes
description: Short, copy-ready how-tos for the things you do most in Beak: a resource, a row action, a KPI, a kanban board, a badge column, a picker, and a CSV export.
---

# Common recipes

A grab-bag of small, worked answers to "how do I do that one thing". Each recipe
is a few lines of real code and a link to the page that covers it in depth. Skim
for the one you need; every snippet is lifted from a running demo app.

Unless a recipe says otherwise, the code is from the reference admin store
(`reference_admin`, served on port 8080). The kanban recipe uses the showcase
app (`beak_superdashboard`, port 8180); it is labelled where it appears.

## Add a resource end-to-end

Once a model exists, two moves turn it into a full CRUD page. First register it,
so both the backend and the panel know its shape:

```dart title="apps/reference_admin_models/lib/reference_admin_models.dart"
BeakModelRegistry buildReferenceRegistry() {
  final registry = BeakModelRegistry();
  for (final model in referenceModels) {
    registry.register(model);
  }
  return registry;
}
```

Then declare a `BeakResource` for it in the panel config. That single line
yields the list, detail, create, and edit pages, plus navigation:

```dart title="apps/reference_admin/lib/main.dart"
BeakResource(
  model: CategoryModel(),
  icon: BeakIconToken(OiIcons.folderTree),
),
```

→ [Defining models](../models/defining-models.md) and
[The generated API](../backend/the-generated-api.md).

## A custom row action

When a resource needs a verb the CRUD basics do not cover, write plain typed
code over the data source and surface it as a `BeakRecordAction`. This one
duplicates a product, reading fields through column constants and never strings:

```dart title="apps/reference_admin/lib/main.dart"
Future<void> duplicateProduct(
  BeakRecord record,
  BeakActionContext context,
) async {
  final String? name = switch (record[ProductColumns.name.key]?.raw) {
    final String value => value,
    _ => null,
  };
  if (name == null) {
    throw const BeakConfigurationException(
      'Cannot duplicate a product that has no name.',
    );
  }
  await context.dataSource.create(
    context.model.table,
    BeakRecord(values: {
      ProductColumns.name.key: BeakStringValue('$name (copy)'),
    }),
  );
  await context.refresh?.call();
}
```

Wire it into the resource as an action:

```dart title="apps/reference_admin/lib/main.dart"
recordActions: [
  BeakRecordAction(
    key: 'duplicate',
    label: 'Duplicate',
    icon: OiIcons.copy,
    onExecute: duplicateProduct,
  ),
],
```

→ [Actions](../panel/actions.md).

## A KPI on the dashboard

A stat tile is an aggregate spec plus a label. The count runs in the database;
no rows are loaded to produce the number:

```dart title="apps/reference_admin/lib/main.dart"
dashboardStats: [
  const BeakStat(
    label: 'Products',
    aggregate: BeakAggregateSpec.count(table: 'products'),
    icon: OiIcons.package,
  ),
  BeakStat(
    label: 'Catalog value',
    aggregate: BeakAggregateSpec.sum(
      table: 'products',
      column: ProductColumns.price,
    ),
    icon: OiIcons.euro,
    prefix: '€',
  ),
],
```

→ [Dashboards](../panel/dashboards.md).

## A kanban view

A resource can offer more than a table. Add a `BeakKanbanView` alongside
`BeakTableView` and it groups records into columns by an enum field. From the
showcase app (`beak_superdashboard`, port 8180):

```dart title="apps/beak_superdashboard/lib/panel/resources.dart"
viewModes: [
  BeakTableView(),
  BeakKanbanView(
    groupField: OrderColumns.status,
    titleField: OrderColumns.reference,
    subtitleField: OrderColumns.total,
    sortField: OrderColumns.placedAt,
    sortDescending: true,
  ),
],
```

→ [View modes](../panel/view-modes.md).

## An enum badge column

A `BeakEnumColumn` renders as a coloured badge when you give it `badgeColors`.
Map each enum value to a `BeakColor`, and the badge shows up in the table, the
detail row, and the filter without any per-surface code:

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const status = BeakEnumColumn<ProductStatus>(
  key: 'status',
  label: 'Status',
  values: ProductStatus.values,
  defaultValue: ProductStatus.draft,
  filterable: true,
  badgeColors: {
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  },
);
```

→ [Column types](../models/column-types.md).

## A belongs-to picker

Declare a `BeakBelongsTo` relationship and Beak gives you a searchable picker in
the form and a linked label in the table and detail, all from the display column
you name:

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
);
```

List the relationship on the model's `relationships` getter and the picker
appears wherever the resource renders a form.

→ [Relationships](../models/relationships.md) and [Forms](../panel/forms.md).

## Export to CSV

Every resource gets a generated `POST /api/{table}/export` route. From Dart, the
client turns a query spec into a CSV string, so an export honours the same
filters and sorts the table is showing:

```dart title="packages/beak_core/lib/src/client/beak_client.dart"
/// Exports [spec]'s rows as CSV via `POST /api/{table}/export`.
Future<String> export(String table, BeakQuerySpec spec) async {
  final response = await _postJson('/api/$table/export', spec.toJson());
  return response.body;
}
```

Call it with the same spec the current view built:

```dart
final csv = await client.export('products', spec);
```

→ [Search and export](../backend/search-and-export.md).

## Continue reading

- [Actions](../panel/actions.md) the full action model behind the row-action
  recipe.
- [Dashboards](../panel/dashboards.md) more on stat tiles, KPI blocks, and
  charts.
- [Relationships](../models/relationships.md) all four relation kinds and how
  they render.
- [Performance](performance.md) why aggregate KPIs and eager-loaded pickers keep
  query counts flat.
