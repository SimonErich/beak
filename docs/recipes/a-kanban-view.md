---
title: A kanban view
description: Offer a board alongside the table, grouped by an enum column.
---

# A kanban view

A resource can offer more than a table. Add a `BeakKanbanView` alongside
`BeakTableView` in the resource file and it groups records into columns by an
enum field:

```dart title="examples/store/lib/resources/products.dart"
  viewModes: const [
    BeakTableView(),
    BeakKanbanView(
      groupField: ProductColumns.status,
      titleField: ProductColumns.name,
      subtitleField: ProductColumns.sku,
    ),
  ],
```

## Continue reading

- [View modes](../panel/view-modes.md)
