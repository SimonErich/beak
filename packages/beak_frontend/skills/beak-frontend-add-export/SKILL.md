---
name: beak-frontend-add-export
description: Add a CSV export of a Beak list's current query and columns, or a custom export file, without bypassing server authorization. Use when operators want the table as a file.
---

# Add an export

An export downloads the rows of the list's current query, with the same columns
and permission checks as the table.

## Steps

1. The conventional resource already exports the shown fields through the
   panel's `BeakListDefaults`. Add one to a table screen's definition:

   ```dart
   BeakListDefinition(
     export: BeakListExport(
       fileName: 'products.csv',
       fields: [ProductModel.sku, ProductModel.name, ProductModel.status],
     ),
   )
   ```

2. The export runs through the same data source and query as the list, so a
   filter, sort or search applies. The server authorizes it like a read.
3. A custom file (a label, a PDF) is a normal action using the panel's data
   source; keep formatting from `BeakFormatting`.
4. Run `beak prepare` when the wiring changed, then the gate.

## Gate

`flutter analyze`, `flutter test`, and a test that exports one filtered row and
checks the header and value.

## Example prompt

> Use the beak-frontend-add-export skill: export sku, name and status for the product list with the current filter applied.
