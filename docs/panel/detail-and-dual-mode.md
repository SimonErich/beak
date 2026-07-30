---
title: Detail views and dual-mode blocks
description: The show page Beak derives from a model, how to replace it with a block layout, and how one layout drives both the show page and the create/edit form.
---

# Detail views and dual-mode blocks

After this page you can read the show page Beak derives from your schema class,
replace it with a bespoke card-and-tab layout when you want one, and reuse that
layout as the create/edit form so a record's structure lives in one place.

Every resource gets a show page for free, and it is no longer a flat definition
grid. Beak derives a layout from the model: a headline card, the remaining
fields, and one tab per to-many relationship. When you want something else you
declare a `detail` layout, a `const` tree of record-bound blocks. The
interesting part is that the same tree can drive the form, because those blocks
render read-only values under a record scope and editable inputs under a form
scope. One layout, two surfaces.

## The default detail

A resource that declares no `detail` gets the layout its model implies. It is
derived, not generated: no file is written for it, so adding a column to the
schema class changes the show page with nothing to regenerate.

```dart title="packages/beak_frontend/lib/src/detail/beak_default_detail_layout.dart"
--8<-- "packages/beak_frontend/lib/src/detail/beak_default_detail_layout.dart:beakDefaultDetailLayout"
```

The rules in one list:

| Rule | Why |
| --- | --- |
| Only columns whose `visibleOn` includes `BeakContext.detail` appear. | The same set the table and the CSV export read, per context. |
| The primary key and every belongs-to foreign key are dropped. | The relationship renders the related record; the key that stores it is noise. |
| The first four remaining columns become a headline card. | Fields keep the order you declared them in, so the one you wrote first leads. |
| The next eight fill a "Details" card, eight columns wide, two fields across. | Anything beyond that goes in a narrower "More" card beside it. |
| Each to-many relationship gets a tab in a "Related" card. | One relation manager per tab, labelled with the relationship's label. |

### What that gives the store's orders

The store's `Order` declares five fields, a `@BelongsTo` customer, a `@HasMany`
of lines, and `timestamps: true`:

```dart title="examples/store/lib/models/order.dart"
@Resource(timestamps: true)
final class Order extends BeakSchema {
  /// The human-readable order number.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    unique: true,
    rules: [BeakMaxLength(40)],
  )
  late final String reference;

  /// Where the order is in its lifecycle.
  @Column(filterable: true)
  @Badges({
    OrderStatus.pending: BeakColor.warning,
    OrderStatus.paid: BeakColor.info,
    OrderStatus.shipped: BeakColor.success,
    OrderStatus.refunded: BeakColor.error,
  })
  late final OrderStatus status;

  /// Order total in euros.
  @Column(prefix: '€', sortable: true, rules: [BeakMin(0)])
  late final double total;

  /// When the order was placed.
  @Column(sortable: true, filterable: true)
  late final DateTime placedAt;

  /// Delivery notes for the courier.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? notes;

  /// The customer who placed it.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final User customer;

  /// The lines on the order.
  @HasMany(onDelete: BeakOnDelete.cascade)
  late final List<OrderItem> items;
}
```

Its resource file sets `formSteps` and nothing else, so the show page is the
derived one:

- a headline card with **Reference**, **Status** (as its badge), **Total** (with
  its `€` prefix) and **Placed At**;
- a "Details" card with **Notes**, **Created** and **Updated**;
- a "Related" card with one tab, **Items**, holding the order's lines.

`customer_id` never appears: it is form-only, and the derived layout would have
dropped it anyway.

!!! note "What just happened"
    - You wrote a schema class, and a resource file that only talks about the
      create/edit form.
    - The show page came out of the model, tabs and all.
    - Nothing was written to a file for it, so the page follows the class.

When a resource declares no `detail`, the show page also knows exactly which
relations it is about to render, so it loads them with the record in one query:

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
final result = await beakLoadRecordWithRelations(
  BeakResourceRepository(dataSource),
  model: model,
  id: recordId,
  relations: resource.detail != null
      ? const []
      : [
          for (final relation in model.relationships)
            if (relation.cardinality == BeakRelationCardinality.many)
              relation,
        ],
);
```

A custom layout renders whichever blocks it names, which the page cannot know
statically, so those blocks fetch their own.

`BeakDetailView`, the flat definition grid, is still exported and still renders
a model's detail columns as labelled rows if you want it inside a screen or a
block tree. The show page no longer reaches for it.

That the detail cell and the table cell come from the same `renderBeakCell` is
the [rendering-per-surface](../concepts/rendering-per-surface.md) promise: one
column, formatted the same wherever it appears.

## A custom detail layout

Set `detail` on the resource and your tree replaces the derived one. You do not
write a `BeakResource` to do it: `lib/resources/<table>.dart` receives the
generated resource and returns a copy.

```bash
beak eject resource products
```

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  // ...record actions, bulk actions, view modes
);
```

Declared or derived, the show page renders one block tree inside the loaded
record's scope, so any field block inside resolves its value from that one
record:

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
(final BeakRecord value, _) => SingleChildScrollView(
  child: BeakRecordScope(
    model: model,
    record: value,
    child: BeakBlockHost(block: resource.effectiveDetail),
  ),
),
```

`effectiveDetail` is the whole of the decision:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
BeakBlock get effectiveDetail => detail ?? beakDefaultDetailLayout(model);
```

The layout is composed from three record-bound blocks and any layout containers
you like (cards, grids, tabs). Each is a plain `const` leaf:

| Block | Renders |
| --- | --- |
| `BeakFieldBlock(column)` | one field: a label and the record's value for `column`, formatted like the table |
| `BeakFieldGroupBlock(columns, columnCount:)` | a responsive definition grid of several fields |
| `BeakRelationBlock(relationship)` | the record's related records through the shared relation manager |

`BeakFieldBlock` resolves its value from the enclosing scope, which is why it
can be `const`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_field_block.dart:BeakFieldBlock"
```

See [Record blocks](../blocks/record-blocks.md) for the full field list of each
block, and [The block system](../concepts/the-block-system.md) for how a block
tree renders.

## One layout, two surfaces

Here is the part worth the page. The store defines its product layout once and
hands it to the resource as both `detail` and `formLayout`. On the show page the
field blocks render values; on the create/edit form the same blocks render
inputs. The layout decides the field set as well as the structure: a form column
the layout does not name gets no input.

```dart title="examples/store/lib/resources/products.dart"
/// The product layout, used for **both** the show page and the create/edit
/// form: the dual-mode blocks render values on one and inputs on the other,
/// so the two pages cannot drift apart.
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
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 8),
          title: 'Overview',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ProductColumns.summary),
              BeakFieldBlock(ProductColumns.description),
              BeakFieldGroupBlock([
                ProductColumns.stock,
                ProductColumns.featured,
                ProductColumns.publishedAt,
                ProductColumns.swatch,
              ], columnCount: 4),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Media',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(ProductColumns.image),
              BeakFieldBlock(ProductColumns.specSheet),
            ],
          ),
        ),
      ],
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

`ProductColumns` and `ProductRelations` are generated from the `@Resource`
class in `lib/models/product.dart`, so a renamed field is a compile error in
this file rather than a blank card in production.

!!! warning "A layout is an allow-list"
    A layout-driven form registers exactly the columns its field blocks name.
    The store's `metadata` column appears nowhere in `productLayout`, so the
    product form does not ask for it and the show page does not print it. Add a
    `BeakFieldBlock(ProductColumns.metadata)` when you want it back.

### How the blocks decide

The block host renders a field block by looking for a form scope first, then a
record scope, and nothing outside both. A `BeakDataForm` with a `layout`
installs a `BeakFormScope` around the block host; the show page installs a
`BeakRecordScope`. The block reads whichever is above it.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _field(BuildContext context, BeakFieldBlock block) {
  final form = BeakFormScope.of(context);
  if (form != null) {
    return _fieldInput(form, block.column);
  }
  final scope = BeakRecordScope.of(context);
  if (scope == null) {
    return const SizedBox.shrink();
  }
  final String label = block.label ?? block.column.label;
  final Widget value = renderBeakCell(
    context,
    column: block.column,
    record: scope.record,
    renderContext: BeakContext.detail,
  );
  // ...stacked or inline label + value
}
```

In a form scope, a field block becomes a belongs-to picker for a foreign key or
the type-mapped input otherwise, and renders nothing for a column the form did
not register (the id, or a detail-only field):

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _fieldInput(BeakFormScope form, BeakColumn column) {
  final controller = form.controller;
  if (!controller.hasFieldFor(column)) {
    return const SizedBox.shrink();
  }
  for (final relation in form.model.relationships) {
    if (relation is BeakBelongsTo && relation.foreignKey == column.key) {
      return BeakBelongsToField(
        controller: controller,
        relation: relation,
        dataSource: form.dataSource,
        referenceCache: beakLocator<ReferenceCache>(),
      );
    }
  }
  return beakFormFieldFor(
        controller: controller,
        column: column,
        uploader: form.uploader,
        filePicker: form.filePicker,
      ) ??
      const SizedBox.shrink();
}
```

The two scopes are `InheritedWidget`s that carry exactly what each surface
needs. The record scope carries the loaded record so read-only blocks can format
it:

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
static BeakRecordScope? of(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<BeakRecordScope>();
```

The form scope carries the controller and the upload wiring so input blocks can
bind their fields. Because the form registers precisely the columns the layout
addresses, the layout is the single source of truth for both the structure and
the field set.

!!! note "What just happened"
    - You wrote the product layout once, in `lib/resources/products.dart`.
    - Passed to `detail`, its field blocks render values from the loaded record.
    - Passed to `formLayout`, the same field blocks render inputs bound to the
      form controller.
    - A relation block becomes a read-only relation manager on the show page and
      an editable one (once the record is saved) on the form.

### Relation blocks in each mode

A `BeakRelationBlock` follows the same rule. On the show page it renders the
scoped record's relation manager. In a form it can only manage a to-many
relation once the parent exists, so in create mode it prompts the user to save
first:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _relation(BuildContext context, BeakRelationBlock block) {
  final form = BeakFormScope.of(context);
  if (form != null) {
    // In a form, a to-many relation can only be managed once the parent
    // exists — create mode has no id to attach to yet.
    final Object? editingId = form.recordId;
    if (editingId == null) {
      return OiLabel.caption(
        'Save first to manage ${block.relationship.label.toLowerCase()}.',
      );
    }
    return BeakRelationManager(
      parentModel: form.model,
      parentId: editingId,
      relationship: block.relationship,
      dataSource: form.dataSource,
    );
  }
  // ...falls through to the record scope's relation manager
}
```

On the show page the manager is handed whatever the page already loaded, so a
derived layout's tabs paint without a second request:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
return BeakRelationManager(
  parentModel: scope.model,
  parentId: id,
  relationship: block.relationship,
  dataSource: beakLocator<BeakDataSource>(),
  // The page that loaded this record may have loaded its relations with
  // it; when it did, the manager paints without a query of its own.
  initialRecords: scope.record.relations[block.relationship.key],
);
```

## When to reach for which

- **No `detail`, no `formLayout`.** The derived show page and a flat form. The
  fastest start, and most resources stay here. The store's categories, tags,
  users and roast profiles all do.
- **`detail` only.** A custom show page, a plain flat form. Good when the record
  reads richly but edits plainly.
- **`detail` and `formLayout` set to the same tree.** One structure for both
  surfaces, as the store's products resource does.
- **`formSteps`.** A paced wizard instead of a layout, for long entities, as the
  store's orders resource does. See [Multi-step forms](multi-step-forms.md).
  `formSteps` takes precedence over `formLayout`.

The first needs no file at all. The other three live in
`lib/resources/<table>.dart`, one file per resource, and every resource without
one keeps its generated defaults.

## Continue reading

- [Forms](forms.md) the flat form and how columns become inputs.
- [Multi-step forms](multi-step-forms.md) the wizard alternative to a layout.
- [Resources](resources.md) where `detail` and `formLayout` are declared, and what else that file can change.
- [Record blocks](../blocks/record-blocks.md) the field, field-group, and relation blocks in full.
- [Rendering per surface](../concepts/rendering-per-surface.md) why a value looks the same in the table and the detail.
- [Relationships](../models/relationships.md) what the relation manager attaches and detaches.
