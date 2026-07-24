---
title: 6. Filters, actions, and view modes
description: Add a status filter and a name search to products, a Duplicate row action, and a kanban board view for orders, all from typed configuration.
---

# 6. Filters, actions, and view modes

Your tables now hold data. This chapter makes them usable. By the end the
products list has a Status dropdown and a Name search box, each product row gains
a Duplicate action, and (as an add-on to your store) orders get a board view
grouped by status. Every one of these is typed configuration on a
`BeakResource`, not a hand-written page.

## Filters

A filter is declared once, over a column you already have. The sealed
`BeakFilterDef` family fixes how each renders and which predicate it contributes,
so the filter bar switches over the variants exhaustively and no
`Map<String, dynamic>` ever appears. Add two to the products resource:

```dart title="apps/reference_admin/lib/main.dart"
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
      filters: [
        BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
        BeakTextFilter(column: ProductColumns.name, label: 'Name'),
      ],
    ),
```

`BeakSelectFilter` renders as a dropdown and constrains its column to the chosen
value (`eq`). It needs an enum column: it reads the options straight off
`ProductColumns.status`, so the dropdown always matches the model. `BeakTextFilter`
renders as a text box and constrains its column with `contains`; an empty box
contributes no predicate at all.

Because both filters point at columns you already declared, there is nothing else
to wire. The list page reads `resource.filters`, builds the bar, and re-queries
the backend on every change. Reload the panel and the Products page has a filter
row: pick `published` and only published products remain; type `esp` in Name and
the list narrows to Espresso Beans.

!!! note "One column, many jobs"
    `ProductColumns.status` was declared once in chapter 4 with `filterable:
    true`. That single `const` already drove the table badge and the form select.
    Now it drives the filter dropdown too, with no new field reference and no
    string keys.

## A row action

The built-in view, edit, and delete actions are always present. A
`BeakRecordAction` adds your own. Its `onExecute` receives the target record and
a `BeakActionContext`: the model, the data source, the router, and a `refresh`
hook for the surface it ran from.

Here is the store's real Duplicate action. It reads the source record through the
shared `ProductColumns` constants (never string literals), writes a `(copy)`
clone through the data source, then refreshes the list.

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
    BeakRecord(
      values: {
        ProductColumns.name.key: BeakStringValue('$name (copy)'),
        if (record[ProductColumns.price.key] case final BeakValue price)
          ProductColumns.price.key: price,
        if (record[ProductColumns.status.key] case final BeakValue status)
          ProductColumns.status.key: status,
        if (record[ProductColumns.categoryId.key] case final BeakValue category)
          ProductColumns.categoryId.key: category,
      },
    ),
  );
  await context.refresh?.call();
}
```

Two details worth pausing on. The record is read by pattern matching on
`BeakValue`, not by casting, so a missing or wrong-typed field falls through to a
safe branch instead of throwing. And the action never captures widget state: it
reaches for everything it needs through `context`, which is what lets Beak run
the same function from a table row or a detail page.

Wire it into the resource as a record action:

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

Reload the panel. Each product row's action menu now has Duplicate; running it
adds an `Espresso Beans (copy)` and the list refreshes on its own.

## A board view for orders

A resource always has a table view. Declaring extra view modes puts a switcher
above the list. Each mode builds a block from the model, so a view mode is typed
configuration, not a widget.

Your store's `Order` has no status to group by, so this section is an add-on:
here is how you would give orders a kanban board. First, give the order a status.
Add an enum and a `BeakEnumColumn` to the store's order model, exactly as you did
for products:

```dart title="apps/reference_admin_models/lib/src/order.dart"
/// Fulfilment state of an order.
enum OrderStatus { pending, paid, shipped, delivered }

  // add to OrderColumns:
  static const status = BeakEnumColumn<OrderStatus>(
    key: 'status',
    label: 'Status',
    values: OrderStatus.values,
    defaultValue: OrderStatus.pending,
    filterable: true,
    badgeColors: {
      OrderStatus.pending: BeakColor.warning,
      OrderStatus.paid: BeakColor.info,
      OrderStatus.shipped: BeakColor.primary,
      OrderStatus.delivered: BeakColor.success,
    },
  );
```

Add `status` to `OrderColumns.values` so it renders, then give the orders table a
column to store it. Since these are your own new tables, extend the
`CreateOrdersTable` migration with a defaulted status column, mirroring the
products migration:

```dart title="apps/reference_admin_server/lib/src/migrations/reference_migrations.dart"
    await schema.create('orders', (table) {
      table.idUuid();
      table.string('reference', length: 40);
      table.string('status', length: 20).withDefault('pending');
      table.decimal('total');
      table.dateTime('placed_at').makeNullable();
      table.uuid('user_id').makeNullable();
      table.unique(['reference']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
```

Now declare a `BeakKanbanView` on the orders resource. `groupField` is the enum
whose values become the board's columns; `titleField` and `subtitleField` fill
each card; `sortField` orders cards within a column.

```dart title="apps/reference_admin/lib/main.dart"
    BeakResource(
      model: OrderModel(),
      icon: BeakIconToken(OiIcons.shoppingCart),
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
    ),
```

Keep `BeakTableView()` first so the table stays the default; the kanban view adds
a Board segment beside it. Every field named here is a real `OrderColumns`
constant on your store's model, which is what keeps the board type-safe.

!!! warning "This is an add-on, not shipped code"
    The reference store's `Order` does not include a status column. The enum,
    the migration change, and the board above are the minimal correct way to add
    one to your own store. The showcase app (`beak_superdashboard`) ships a
    fuller order status with six states; do not copy its column constants into
    the reference store.

## Run it

If you added the order board, rebuild the schema so the new status column exists,
re-seeding as you go:

```bash
cd apps/reference_admin_server
dart run bin/worm.dart migrate:fresh --seed
```

`migrate:fresh` drops and re-applies every migration, then `--seed` runs the
`ReferenceSeeder` again. Your seeded order has no explicit status, so it takes the
`pending` default.

Then restart the backend and run the panel:

```bash
cd apps/reference_admin
flutter run -d chrome
```

The Products list now shows a Status dropdown and a Name box across the top, and
each row's action menu offers Duplicate. If you added the board, the Orders page
shows a Table / Board switch, and on Board the orders sit in columns by status.

!!! note "What just happened"
    - Two filters and a record action turned a plain list into a working
      workspace, all as configuration on the `BeakResource`.
    - The action read and wrote records through typed `BeakValue`s and the
      `BeakActionContext`, with no widget state and no casts.
    - A view mode is a block built from the model. Adding `BeakKanbanView` to
      `viewModes` gave orders a second presentation without a new page.

## Continue reading

- [7. A custom dashboard](07-a-custom-dashboard.md) put your data on the front
  page with stat cards and a chart.
- [View modes](../panel/view-modes.md) table, calendar, and kanban views and
  when to reach for each.
- [Actions](../panel/actions.md) record, bulk, and global actions, confirmation
  dialogs, and optimistic undo.
