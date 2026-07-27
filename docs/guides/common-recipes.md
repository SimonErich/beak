---
title: Common recipes
description: Short, copy-ready how-tos for the things you do most in Beak: a resource, a row action, a KPI, a kanban board, a badge column, a picker, a wizard, and a CSV export.
---

# Common recipes

A grab-bag of small, worked answers to "how do I do that one thing". Each recipe
is a few lines of real code and a link to the page that covers it in depth. Skim
for the one you need; every snippet is lifted from a running example app or from
Beak's own source.

Unless a recipe says otherwise, the code is from the store example
(`examples/store`, served on port 8080). One snippet comes from the showcase app
(`examples/superdashboard`, port 8180) and one from `beak_core`; both are
labelled where they appear.

## Add a resource end-to-end

Write one annotated class under `lib/models/`. The field's type picks the column
kind, and its nullability decides whether the value is required:

```dart title="examples/store/lib/models/tag.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'tag.beak.dart';

/// A free-form label products are tagged with.
@Resource()
final class Tag extends BeakSchema {
  /// What the tag is called.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    unique: true,
    rules: [BeakMaxLength(60)],
  )
  late final String name;
}
```

Then run the generator:

```bash
beak prepare
```

That writes `tag.beak.dart` beside it (`TagColumns`, `TagRelations`,
`TagModel`, a typed record view), adds the model to `beakModels` and the
registry, adds the resource to the panel config, and writes the migration the
new table needs. You register nothing. Give it an icon and a sidebar section in
`beak.yaml` if the defaults are not what you want.

→ [Defining a resource](../models/defining-models.md) and
[Generated code](../models/generated-code.md).

## A custom row action

When a resource needs a verb the CRUD basics do not cover, add it in
`lib/resources/<table>.dart`. That file takes the generated `BeakResource` and
returns a changed copy, so the model, label, icon and section stay generated:

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  // ...detail and formLayout...
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
  // ...bulkActions and viewModes...
);
```

The action reads and writes through generated column constants, never through a
string field reference, so renaming `publishedAt` in the schema class breaks the
build here rather than in production.

→ [Actions](../panel/actions.md).

## A KPI on the dashboard

Add `lib/dashboard.dart` declaring `BeakScreen beakDashboard()` and it replaces
the generated page at `/`. A KPI is an aggregate spec plus a title: the number
is computed in the database, and no rows are loaded to produce it.

```dart title="examples/store/lib/dashboard.dart"
const BeakBlock _kpis = BeakGridBlock(
  columns: 4,
  children: [
    BeakKpiBlock(
      title: 'Revenue',
      value: BeakAggregateSpec.sum(table: 'orders', column: OrderColumns.total),
      format: BeakKpiFormat.currency,
      currencySymbol: '€',
    ),
    BeakKpiBlock(
      title: 'Orders',
      value: BeakAggregateSpec.count(table: 'orders'),
    ),
    // ...'Awaiting payment' and 'Out of stock', each a filtered count.
  ],
);
```

→ [Dashboards](../panel/dashboards.md).

## A kanban view

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

→ [View modes](../panel/view-modes.md).

## An enum badge column

Declare the field as your enum and Beak renders a select in the form and a
badge everywhere else. `@Badges` maps each value to a colour, and the badge
shows up in the table, the detail row and the filter without any per-surface
code:

```dart title="examples/store/lib/models/product.dart"
  /// Lifecycle state, rendered as a coloured badge.
  @Column(filterable: true)
  @Badges({
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  })
  late final ProductStatus status;
```

→ [Column types](../models/column-types.md).

## A belongs-to picker

Point a field at another schema class and annotate it `@BelongsTo`. Beak
generates the foreign-key column, both sides of the relationship, a searchable
picker in the form and a linked label in the table and detail:

```dart title="examples/store/lib/models/product.dart"
  /// The category this product is filed under.
  @BelongsTo(onDelete: BeakOnDelete.setNull)
  late final Category? category;
```

The picker searches the related model's display column by default. When people
look a record up by something else, widen it with `searchOn`, and rename the
relationship with `label` (from the showcase app):

```dart title="examples/superdashboard/lib/models/invoices/invoice.dart"
  /// The billed user.
  @BelongsTo(label: 'Bill to', searchOn: ['name', 'email'])
  late final User? user;
```

→ [Relationships](../models/relationships.md) and [Forms](../panel/forms.md).

## Hide a resource from the sidebar

A join table or a child model usually has no business in the navigation, but it
still needs its model, its API and its relationships. Set `hidden: true` on it
in `beak.yaml`; that is the only change:

```yaml title="examples/store/beak.yaml"
resources:
  products:
    icon: package
    section: Catalog
  # ...categories, tags, roast_profiles, orders, users...
  order_items:
    hidden: true
```

The showcase app leans on this hard: 49 models, 17 of them navigable.

→ [beak.yaml](../reference/beak-yaml.md).

## Split a long form into steps

A create form with nine inputs is a wall. Give the resource `formSteps` and each
step validates before the next one opens:

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
    // ...'Order', 'Money' and 'Delivery', covering every remaining column.
  ],
);
```

Every form column must appear in exactly one step.

→ [Multi-step forms](../panel/multi-step-forms.md).

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
- [Dashboards](../panel/dashboards.md) more on KPI blocks, metrics, and charts.
- [Relationships](../models/relationships.md) all four relation kinds and how
  they render.
- [beak.yaml](../reference/beak-yaml.md) every key that shapes the panel from
  outside Dart.
- [Performance](performance.md) why aggregate KPIs and eager-loaded pickers keep
  query counts flat.
