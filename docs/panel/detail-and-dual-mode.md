---
title: Detail views and dual-mode blocks
description: How Beak generates a record's show page, how to give it a custom layout, and how one block tree drives both the show page and the form.
---

# Detail views and dual-mode blocks

After this page you can render any record's show page with zero code, replace it with a bespoke card-and-tab layout when you want one, and reuse that same layout as the create/edit form so a field's structure lives in one place.

Every resource gets a show page for free. By default it is a definition grid of the record's detail columns. When you want more, you declare a `detail` layout: a `const` tree of record-bound blocks. The interesting part is that the very same tree can drive the form, because those blocks render read-only values under a record scope and editable inputs under a form scope. One layout, two surfaces.

## The default detail

`BeakDetailView` is the generated read-only view. It renders each column whose `visibleOn` includes `BeakContext.detail` as a labelled row, formatted by the shared cell renderer, so a badge, a date, an image, or a color swatch looks exactly like it does in the table.

```dart title="packages/beak_frontend/lib/src/detail/beak_detail_view.dart"
final detailColumns = [
  for (final column in model.columns)
    if (column.visibleOn.contains(BeakContext.detail)) column,
];
return OiCard(
  title: const OiLabel.h4('Details'),
  child: OiGrid(
    breakpoint: context.breakpoint,
    minColumnWidth: const OiResponsive<double>(240),
    gap: const OiResponsive<double>(16),
    children: [
      for (final column in detailColumns)
        OiColumn(
          // ...
          children: [
            OiLabel.caption(column.label),
            renderBeakCell(
              context,
              column: column,
              record: record,
              renderContext: BeakContext.detail,
            ),
          ],
        ),
    ],
  ),
);
```

When a resource declares no `detail`, the show page renders this grid and then a `BeakRelationManager` for each to-many relationship, so you can attach and detach related records without leaving the page:

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
null => OiColumn(
  // ...
  children: [
    BeakDetailView(model: model, record: value),
    for (final relationship in model.relationships)
      if (relationship.cardinality == BeakRelationCardinality.many)
        BeakRelationManager(
          parentModel: model,
          parentId: recordId,
          relationship: relationship,
          dataSource: dataSource,
        ),
  ],
),
```

That the detail cell and the table cell come from the same `renderBeakCell` is the [rendering-per-surface](../concepts/rendering-per-surface.md) promise: one column, formatted the same wherever it appears.

## A custom detail layout

Set `detail` on the resource to a `BeakBlock` tree. The show page renders it inside the loaded record's scope, so any field block inside resolves its value from that one record.

```dart title="packages/beak_frontend/lib/src/pages/beak_resource_pages.dart"
final BeakBlock layout => BeakRecordScope(
  model: model,
  record: value,
  child: BeakBlockHost(block: layout),
),
```

The layout is composed from three record-bound blocks and any layout containers you like (cards, grids, tabs). Each is a plain `const` leaf:

| Block | Renders |
| --- | --- |
| `BeakFieldBlock(column)` | one field: a label and the record's value for `column`, formatted like the table |
| `BeakFieldGroupBlock(columns, columnCount:)` | a responsive definition grid of several fields |
| `BeakRelationBlock(relationship)` | the record's related records through the shared relation manager |

`BeakFieldBlock` resolves its value from the enclosing scope, which is why it can be `const`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
final class BeakFieldBlock extends BeakBlock {
  const BeakFieldBlock(
    this.column, {
    this.label,
    this.layout = BeakFieldLayout.stacked,
    super.span,
  });

  final BeakColumn column;
  final String? label;
  final BeakFieldLayout layout;
}
```

See [Record blocks](../blocks/record-blocks.md) for the full field list of each block, and [The block system](../concepts/the-block-system.md) for how a block tree renders.

## One layout, two surfaces

Here is the part worth the page. The showcase app defines its product layout once and hands it to the resource as both `detail` and `formLayout`. On the show page the field blocks render values; on the create/edit form the same blocks render inputs. Each form column appears exactly once.

```dart title="apps/beak_superdashboard/lib/panel/details/commerce_layouts.dart"
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
              BeakFieldBlock(ProductColumns.description),
              BeakFieldGroupBlock([
                ProductColumns.cost,
                ProductColumns.stock,
                ProductColumns.categoryId,
              ], columnCount: 3),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 4),
          title: 'Primary image',
          child: BeakFieldBlock(ProductColumns.image),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Related',
      child: BeakTabsBlock(
        tabs: [
          BeakTabBlockItem(
            label: 'Variants',
            icon: OiIcons.layers,
            content: BeakRelationBlock(ProductRelations.variants),
          ),
          // ...pricing rules, gallery, reviews, order history, tags
        ],
      ),
    ),
  ],
);
```

Wiring is one line each on the resource (superdashboard, port 8180):

```dart title="apps/beak_superdashboard/lib/panel/resources.dart"
BeakResource(
  model: ProductModel(),
  icon: BeakIconToken(OiIcons.package),
  section: 'Store',
  detail: productLayout,
  formLayout: productLayout,
  // ...filters
),
```

### How the blocks decide

The block host renders a field block by looking for a form scope first, then a record scope, and nothing outside both. A `BeakDataForm` with a `layout` installs a `BeakFormScope` around the block host; the show page installs a `BeakRecordScope`. The block reads whichever is above it.

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

In a form scope, a field block becomes a belongs-to picker for a foreign key or the type-mapped input otherwise, and renders nothing for a column the form did not register (the id, or a detail-only field):

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

The two scopes are `InheritedWidget`s that carry exactly what each surface needs. The record scope carries the loaded record so read-only blocks can format it:

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
static BeakRecordScope? of(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<BeakRecordScope>();
```

The form scope carries the controller and the upload wiring so input blocks can bind their fields. Because the form registers precisely the columns the layout addresses, the layout is the single source of truth for both the structure and the field set.

!!! note "What just happened"
    - You wrote the product layout once.
    - Passed to `detail`, its field blocks render values from the loaded record.
    - Passed to `formLayout`, the same field blocks render inputs bound to the form controller.
    - A relation block becomes a read-only relation manager on the show page and an editable one (once the record is saved) on the form.

### Relation blocks in each mode

A `BeakRelationBlock` follows the same rule. On the show page it renders the scoped record's relation manager. In a form it can only manage a to-many relation once the parent exists, so in create mode it prompts the user to save first:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _relation(BuildContext context, BeakRelationBlock block) {
  final form = BeakFormScope.of(context);
  if (form != null) {
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

## When to reach for which

- **No `detail`, no `formLayout`.** The generated grid detail and a flat form. The fastest start; most resources live here.
- **`detail` only.** A custom show page, a plain flat form. Good when the record reads richly but edits simply.
- **`detail` and `formLayout` set to the same tree.** One structure for both surfaces, as the product and order resources do.
- **`formSteps`.** A paced wizard instead of a layout, for long entities. See [Multi-step forms](multi-step-forms.md). `formSteps` takes precedence over `formLayout`.

## Continue reading

- [Forms](forms.md) the flat form and how columns become inputs.
- [Multi-step forms](multi-step-forms.md) the wizard alternative to a layout.
- [Record blocks](../blocks/record-blocks.md) the field, field-group, and relation blocks in full.
- [Rendering per surface](../concepts/rendering-per-surface.md) why a value looks the same in the table and the detail.
- [Relationships](../models/relationships.md) what the relation manager attaches and detaches.
