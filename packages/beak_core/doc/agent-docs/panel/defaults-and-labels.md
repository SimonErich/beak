# Defaults, labels and standard resources

> One conventional resource and one list shape for the whole panel, so a resource declaration stays a few lines.

After this page you can declare a resource in one line, change the list shape
for every resource at once, and leave every label to the model.

## At a glance

| You want | Use |
| --- | --- |
| A list, detail page and forms in one line | `BeakResource.standard` |
| One list shape for every resource | `BeakPanelConfig.defaults` |
| The same list on a resource with its own screens | `BeakTableScreen.standard` |
| Model, field, enum and command names in each language | [Label files](labels.md) |
| The open record's children | `BeakRelatedList` |

## The conventional resource

`BeakResource.standard` is the shape most admin screens share: a list, a detail
page and the create/edit forms, with the model's own fields.

```dart
BeakResource.standard(const ProductModel())
```

Pass `columns` to choose the table columns, `form` for the form's own inputs,
and `tabs` to replace the single card with a General tab plus your tabs:

```dart
BeakResource.standard(
  const ProductModel(),
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

## Labels

`BeakResource.standard` and `BeakTableScreen.standard` take no labels: the
title is the model's plural, each column and input reads its field's label,
and the General and Details tabs are Beak's own words. The labels come from the
schema, or from label files in every language the panel speaks; see
[Labels in every language](labels.md). A `label:` where a field is placed
always wins.

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
- A `label:` where a field is placed beats the model's label; without one the field reads the model's label in the panel's language.
- `translationsForm` requires `BeakAdmission.translation` on the target model.

## Verify it

- `BeakResource.standard(model)` titles its list with the model's plural and
  its form tab "General" in the panel's language.
- `beakRouteSweep` visits the standard resource's list, detail and form routes.

## Reference

- `packages/beak_frontend/lib/src/panel/beak_standard_resource.dart`
- `packages/beak_frontend/lib/src/panel/beak_panel_config.dart`
- `packages/beak_core/lib/src/localization/beak_labels.dart`
- `packages/beak_frontend/lib/src/panel/beak_resource_screen.dart`

## Continue reading

- [Labels in every language](labels.md): model and field names from ARB files.
- [Resources](resources.md): the resource declaration and its actions.
- [Tables and filters](tables-and-filters.md): columns, filters and list presets.
- [Testing](../shipping/testing.md): the route sweep that proves every screen renders.
