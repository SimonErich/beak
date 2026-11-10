---
name: beak-frontend-add-list
description: Replace or extend a resource's generated list with chosen columns, filters, presets and row actions in a Beak panel. Use when the table should show different fields, a filter or a saved view.
---

# Add or shape a list

A resource without a list screen already gets one from the model. Add a
`BeakTableScreen` only when the columns, filters or presets differ.

## Steps

1. Open the resource and the generated model. Use static field references,
   never column strings: `ProductModel.sku`, `ProductModel.category.name`.
2. Add the screen:

   ```dart
   BeakTableScreen(
     fields: [ProductModel.sku, ProductModel.name, ProductModel.status],
     query: const ProductModel().query().orderBy(ProductModel.name),
     definition: BeakListDefinition(
       title: 'Products',
       filters: [
         ProductModel.name.textFilter(label: 'Name'),
         ProductModel.status.selectFilter(label: 'Status'),
       ],
       quickFilters: [ProductModel.status.selectFilter(label: 'Status')],
       pageSize: 25,
     ),
   )
   ```

3. Only fields the model declares exist; a missing field means the schema
   changes first (`beak-serverpod-add-model` in a Serverpod admin).
4. Prefer `BeakResource.standard(model, title, columns:, filters:)` for the
   conventional shape; it fills the page size and export from the panel
   defaults.
5. Run `beak prepare` when the wiring changed, then the gate.

## Gate

`flutter analyze`, `flutter test`, and the route sweep over the list at 375 and
1280 pixels.

## Example prompt

> Use the beak-frontend-add-list skill: show sku, name and status on the product table, add a status quick filter, and sort by name.
