---
title: Shaping the panel
description: Icons, sections, filters, actions, view modes, a shared show/edit layout, a form wizard, a custom screen and the dashboard, each decided in one small file.
---

# Shaping the panel

Your models already produce a working panel. This chapter covers the decisions
Beak cannot read off a schema class: where a resource sits, which filters and
actions it offers, how its show page and form look, and what a reader sees at
`/`. Every override is additive, and a resource you say nothing about stays
generated.

## Presentation lives in beak.yaml

Icons, labels, sidebar sections and visibility are presentation, so they stay
in configuration rather than in Dart.

```yaml title="examples/store/beak.yaml"
name: Beak Store

api:
  baseUrl: http://localhost:8080

resources:
  products:
    icon: package
    section: Catalog
  categories:
    icon: folderTree
    section: Catalog
  tags:
    icon: tag
    section: Catalog
  roast_profiles:
    icon: flame
    section: Catalog
  orders:
    icon: receipt
    section: Sales
  users:
    icon: users
    section: Sales
  order_items:
    hidden: true
```

| Key | What it does |
|---|---|
| `icon` | an `OiIcons` name, shown in the sidebar |
| `label` | the navigation label (defaults to the title-cased table name) |
| `section` | the sidebar group this resource is filed under |
| `hidden` | keeps the resource out of the sidebar |

`name` titles the panel and the login screen. `api.baseUrl` is the origin the
panel calls, where `auto` means the origin that served it, and `server.port`
moves the API off 8080. The file is optional: delete it and Beak names the
panel after your package.

!!! note "What just happened"
    - A table you did not list is still discovered, with a default icon and a
      title-cased label.
    - `hidden: true` removes a sidebar entry and nothing else. `order_items`
      keeps its model, its REST endpoints and its tab on the order's show page.

## Filters follow the columns

You marked a few columns `filterable: true` in
[chapter 2](02-columns-and-validation.md). That is the whole filter
declaration: a resource that lists none of its own derives its filter bar from
the model.

| Column type | Derived control |
|---|---|
| enum | a select of its values |
| `bool` | a switch |
| `String`, `BeakText` | a contains-search box |
| `DateTime` | a date range |
| numbers, JSON, colour, rich text, uploads | none, because no control obviously fits |

Declare filters yourself for a different control, a different label, or a
column that derives none. Declaring one replaces the derived set entirely:

```dart
filters: const [
  BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
  BeakTextFilter(column: ProductColumns.name, label: 'Name'),
],
```

## Taking over one resource

That `filters:` argument belongs in `lib/resources/<table>.dart`, the file
holding everything a person decides about a single resource. Scaffold it:

```console
$ beak eject resource products
  created lib/resources/products.dart

  run `beak prepare` to wire it up
```

It starts as one function that changes nothing:
`BeakResource beakResource(BeakResource generated) => generated;`. The
`generated` argument is what Beak derived from the model and `beak.yaml`.
Return it, or return `generated.copyWith(...)`.

| `copyWith` parameter | What it replaces |
|---|---|
| `filters` | the list page's filter bar |
| `recordActions` | per-row actions, beside the built-in view, edit and delete |
| `bulkActions` | actions over the current selection |
| `globalActions` | page-level actions, beside the built-in create |
| `viewModes` | the presentations the list page switches between |
| `detail` | the show page's block tree |
| `formLayout` | the create and edit form's block tree |
| `formSteps` | the form as a wizard, used instead of `formLayout` |
| `label`, `section`, `icon` | navigation, when you would rather decide it in Dart |

Beak discovers the file by name: `products.dart` adjusts the `products`
resource. There is no list to add it to.

## Actions

A record action is a button on each row and on the show page. It receives the
record and a context carrying the model and the data source. The store declares
no `filters` here, so the derived bar stands.

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  recordActions: [
    BeakRecordAction(
      key: 'publish',
      label: 'Publish',
      icon: OiIcons.rocket,
      onExecute: (record, context) async {
        final Object? id = context.model.primaryKeyOf(record);
        if (id == null) {
          return;
        }
        await context.dataSource.update(
          context.model.table,
          id,
          BeakRecord(
            values: {
              ProductColumns.status.key: BeakValue.of(
                ProductStatus.published.name,
              ),
              ProductColumns.publishedAt.key: BeakValue.of(DateTime.now()),
            },
          ),
        );
      },
    ),
  ],
```

The fence stops mid-call: the next two sections finish it. Icons and column
constants need two more imports, `package:beak/ui.dart` and
`../models/product.dart`, and `productLayout` is the constant written further
down, so the file compiles once all three parts are in.

A `BeakBulkAction` in `bulkActions` looks the same, except `onExecute` receives
`List<BeakRecord> records`, so it runs once over the whole selection instead of
once per row. The store has one: an Archive action that walks the selected
products. Both kinds take `color` and `requiresConfirmation: true`, which puts a
dialog in front of the action.

## Two views of one list

A list page renders a table until you give it more than one view mode. Then it
grows a switcher.

```dart title="examples/store/lib/resources/products.dart"
  viewModes: const [
    BeakTableView(),
    BeakKanbanView(
      groupField: ProductColumns.status,
      titleField: ProductColumns.name,
      subtitleField: ProductColumns.sku,
    ),
  ],
);
```

`groupField` has to be an enum column: its values are the board's columns.
`BeakCalendarView` is the third mode, built from a `titleField` and the
`startField` that dates each record.

## One layout for the show page and the form

Without a `detail`, the show page is derived from the model: a headline card of
the display column and the first few fields, the rest in a wide card beside a
narrow one, and one tab per to-many relationship. Adding a column changes that
page with nothing to regenerate.

For a different shape, describe it as blocks. The same tree renders read-only
values on the show page and editable inputs on the form, which is why
`products.dart` passes one constant to both `detail` and `formLayout`.

```dart title="examples/store/lib/resources/products.dart"
const BeakBlock productLayout = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Product',
      child: BeakFieldGroupBlock([
        ProductColumns.name,
        ProductColumns.sku,
        ProductColumns.status,
        ProductColumns.price,
      ], columnCount: 4),
    ),
    BeakCardBlock(
      title: 'Related',
      child: BeakTabsBlock(
        tabs: [
          BeakTabBlockItem(
            label: 'Category',
            icon: OiIcons.folderTree,
            content: BeakFieldBlock(ProductColumns.categoryId),
          ),
          BeakTabBlockItem(
            label: 'Tags',
            icon: OiIcons.tag,
            content: BeakRelationBlock(ProductRelations.tags),
          ),
          BeakTabBlockItem(
            label: 'Sold in',
            icon: OiIcons.receipt,
            content: BeakRelationBlock(ProductRelations.orderItems),
          ),
        ],
      ),
    ),
  ],
);
```

Between those two cards the store's file puts a `BeakGridBlock`: a wide
Overview card holding the remaining fields, beside a narrow Media card for the
image and the spec sheet.

!!! note "What just happened"
    - `BeakFieldBlock` and `BeakFieldGroupBlock` take column constants, so a
      renamed column is a compile error rather than a blank cell.
    - `BeakRelationBlock` takes a relationship constant and renders its manager:
      a table on the show page, an attach control on the form.
    - The two pages cannot drift apart, because there is one tree.

## A form in steps

A create form with nine inputs is a wall. `formSteps` turns it into a wizard.
Each step validates before the next one opens. Listing a column in a step both
selects and orders it, and a column named by no step gets no field at all.

Run `beak eject resource orders`, then fill the function in:

```dart title="examples/store/lib/resources/orders.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  formSteps: const [
    BeakFormStep(
      title: 'Customer',
      subtitle: 'Who is buying',
      icon: OiIcons.user,
      description:
          'Pick the customer this order belongs to. Their past orders appear '
          'on their own page once this one is saved.',
      columns: [OrderColumns.customerId],
    ),
  ],
);
```

The store's file has four steps: customer, order, money, and an optional one
for delivery notes. `formSteps` wins over `formLayout` when both are set.

## A screen of your own

Some pages are not a resource. A file under `lib/screens/` declaring a
top-level `BeakScreen` becomes one, with its own route and sidebar entry.
Write `lib/screens/restock_screen.dart`, with the same three imports a resource
override takes:

```dart title="examples/store/lib/screens/restock_screen.dart"
const BeakScreen restockScreen = BeakScreen(
  path: '/restock',
  title: 'Restock',
  icon: BeakIconToken(OiIcons.packageSearch),
  section: 'Catalog',
  body: BeakColumnBlock(
    gapInPixels: 20,
    children: [
      BeakCardBlock(
        title: 'Running low',
        child: BeakTableBlock(
          model: ProductModel(),
          columns: [
            ProductColumns.name,
            ProductColumns.sku,
            ProductColumns.stock,
            ProductColumns.status,
          ],
          baseFilter: BeakFieldFilter(
            column: ProductColumns.stock,
            operator: BeakOperator.lt,
            value: BeakIntValue(10),
          ),
          initialSpec: BeakQuerySpec(
            table: 'products',
            sorts: [BeakSort('stock')],
          ),
        ),
      ),
    ],
  ),
);
```

The store's file opens with two `BeakMetricBlock` counters above that table,
out of stock and stock on hand. A custom screen is blocks rather than widgets,
so it gets the data wiring, theming and empty states a generated page has.

## The screen at /

`beak eject dashboard` writes `lib/dashboard.dart`, whose `beakDashboard()`
replaces the generated home screen.

```dart title="examples/store/lib/dashboard.dart"
BeakScreen beakDashboard() => const BeakScreen(
  path: '/',
  title: 'Today',
  icon: BeakIconToken(OiIcons.layoutDashboard),
  body: BeakColumnBlock(gapInPixels: 20, children: [_kpis, _revenue, _lists]),
);

const BeakBlock _kpis = BeakGridBlock(
  columns: 4,
  children: [
    BeakKpiBlock(
      title: 'Revenue',
      value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
      format: BeakKpiFormat.currency,
      currencySymbol: '€',
    ),
  ],
);

const BeakBlock _revenue = BeakChartBlock(
  title: 'Order totals',
  type: BeakChartType.bar,
  query: BeakQuerySpec(
    table: 'orders',
    sorts: [BeakSort('placed_at')],
    pagination: BeakPagination(perPage: 30),
  ),
  map: orderTotalPoints,
);
```

A chart queries, then maps. `map` takes a top-level function from the records
the query returned to the points to draw:

```dart title="examples/store/lib/dashboard.dart"
List<BeakChartPoint> orderTotalPoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: OrderColumns.reference.readFrom(record) ?? '—',
      value: OrderColumns.total.readFrom(record) ?? 0,
    ),
];
```

Every figure is a `BeakAggregateSpec` the API computes: nothing is counted in
the browser, nothing is hardcoded. The mapper reads through the generated
column constants, so a renamed column is a compile error rather than an empty
chart. The store's file has three more KPI tiles (orders, awaiting payment, out
of stock) and a `_lists` grid of two `BeakTableBlock` cards. Copy those from the
example, or drop `_lists` from `children` and stop at the chart.

Restart it all:

```console
$ beak dev
```

`beak dev` runs `beak prepare` first, so the sections, actions, view modes,
wizard, screen and dashboard are wired before the API starts. The sidebar now
groups the resources under Catalog and Sales, with Restock among the catalog
entries and no Order Items anywhere. Products has a Table/Board switcher and a
Publish button on every row, an order's create form arrives in four steps, and
`/` is the Today screen.

!!! note "What just happened"
    - Nothing above was registered. A key in `beak.yaml`, a file named after a
      table, a file under `lib/screens/`: `beak prepare` found each one.
    - Everything you did not decide is still derived. The other resources kept
      their generated filters, layouts and pages.

!!! question "What this skipped"
    - The rest of the block catalogue, including the widget escape hatch:
      [Blocks](../blocks/index.md).
    - Colours, typography and the shell: [Theming](../theming/index.md).
    - Every key in one table: [beak.yaml reference](../reference/beak-yaml.md).

## Continue reading

- [Auth, tests, and shipping](06-auth-tests-and-shipping.md) closes the
  tutorial: who signs in, which rows they see, and how to build for production.
- [Seeding and the API](04-seeding-and-the-api.md) is the chapter before this.
- [Tables and filters](../panel/tables-and-filters.md) covers every filter kind.
- [Detail and dual mode](../panel/detail-and-dual-mode.md) explains how one
  block tree renders both values and inputs.
- [Dashboards](../panel/dashboards.md) has the full aggregate and chart surface.
