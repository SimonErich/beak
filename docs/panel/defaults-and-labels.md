---
title: Defaults, labels and standard resources
description: One conventional resource, one list shape and one label mapping for the whole panel, so a resource declaration stays a few lines.
type: guide
audience: [beginner, expert]
status: stable
---

# Defaults, labels and standard resources

After this page you can declare a resource in one line, change the list shape
for every resource at once, and translate enum values, column labels and model
commands through a single mapping.

## At a glance

| You want | Use |
| --- | --- |
| A list, detail page and forms in one line | `BeakResource.standard` |
| One list shape for every resource | `BeakPanelConfig.defaults` |
| German enum, column and command labels | `BeakPanelConfig.labels` |
| The open record's children | `BeakRelatedList` |

## The conventional resource

`BeakResource.standard` is the shape most admin screens share: a list, a detail
page and the create/edit forms, with the model's own fields.

```dart
BeakResource.standard(const ProductModel(), 'Products')
```

Pass `columns` to choose the table columns, `form` for the form's own inputs,
and `tabs` to replace the single card with a General tab plus your tabs:

```dart
BeakResource.standard(
  const ProductModel(),
  'Products',
  columns: [ProductModel.sku, ProductModel.name, ProductModel.status],
  form: [ProductModel.name.input(), ProductModel.status.input()],
  tabs: [BeakTab(title: 'Pricing', children: priceInputs)],
  filters: [ProductModel.status.selectFilter(label: 'Status')],
)
```

`readOnly: true` offers reads only, whatever the model's permissions allow.
The server still enforces its policy on every request.

The detail page shows a metadata aside with the model's created, updated and
deleted timestamps. A screen passes its own `aside`, or sets
`showMetadataAside: false` to use the full width.

## One list shape

`BeakPanelConfig.defaults` is what every resource without its own
`BeakTableScreen` inherits:

```dart
BeakPanelConfig(
  title: 'Shop',
  resources: shopResources,
  defaults: const BeakListDefaults(
    pageSize: 25,
    quickFilters: 3,
    fitRows: true,
    scroll: BeakListScrollMode.page,
  ),
)
```

`standard` reads the same defaults, so a conventional resource and a bare one
page the same way.

## One label mapping

A generated model carries wire values, not display names: an enum value is its
`name`, a column its inventory label. Set one `BeakLabels` and every table
cell, filter, form input and export reads it:

```dart
BeakPanelConfig(
  labels: BeakLabels(
    enumValue: (value) => switch (value) {
      OrderStatus.pending => strings.pending,
      OrderStatus.shipped => strings.shipped,
      _ => null,
    },
    field: (column) => column.key == 'sku' ? strings.sku : null,
    action: (action) => strings.action(action.name),
  ),
)
```

Returning `null` keeps the generated default, so the mapping only lists what it
renames. `BeakColumn.label`, `BeakEnumColumn.labelFor` and
`BeakModelAction.label` consult the mapping, which is why one declaration
reaches tables, filters, forms, exports and confirmation dialogs.

## Related records

`BeakRelatedList` lists the records that point at the open form's record:

```dart
BeakRelatedList(
  const ProductVariantModel(),
  scope: ProductVariantModel.productId,
  parent: ProductModel.id,
  fields: [ProductVariantModel.sku, ProductVariantModel.netPriceCents],
)
```

For the common relationship shapes there are two shortcuts:

- `relation.readOnlyRows(children: [...])` renders a compact read-only table.
- `relation.translationsForm()` reads the target's
  `BeakAdmission.translation` and generates one input per translatable column.
- `toOne.link()` renders the related record's display column as a link to its
  detail page.

## Rules and limits

- A `standard` resource still follows the model's capabilities and
  permissions; `readOnly` only closes what the panel offers.
- A label mapping only renames: a missing entry keeps the generated label.
- `translationsForm` requires `BeakAdmission.translation` on the target model.

## Verify it

- A panel with the mapping renders the translated enum in a table cell and a
  filter.
- `beakRouteSweep` visits the standard resource's list, detail and form routes.

## Reference

- `packages/beak_frontend/lib/src/panel/beak_standard_resource.dart`
- `packages/beak_frontend/lib/src/panel/beak_panel_config.dart`
- `packages/beak_core/lib/src/localization/beak_labels.dart`

## Continue reading

- [Resources](resources.md): the resource declaration and its actions.
- [Tables and filters](tables-and-filters.md): columns, filters and list presets.
- [Testing](../shipping/testing.md): the route sweep that proves every screen renders.
