---
title: Record blocks
description: BeakFieldBlock, BeakFieldGroupBlock, and BeakRelationBlock, the dual-mode blocks that render a read-only detail on one surface and an editable form on another from one layout.
---

# Record blocks

After this page you can write a record layout once and get two surfaces from it:
a read-only detail view and an editable create/edit form. Three blocks bind to
the current record instead of to a query, and they change what they render based
on the scope they find themselves in.

## The dual-mode idea

Most blocks draw the same thing everywhere. Record blocks do not. The same
`BeakFieldBlock(ProductColumns.price)` renders the formatted price on a detail
page and a validated price input on a form page. It decides by looking up the
tree for a scope:

- Inside a **`BeakRecordScope`** (a resource's `detail`), a record block reads
  the scoped record and renders its value, formatted exactly like the table cell
  (badges, dates, images, swatches, relation links).
- Inside a **`BeakFormScope`** (a resource's `formLayout`), the same block
  renders the editable input the form registered for that column, complete with
  the client-side validation that mirrors the server.

Both slots live on the resource, which you adjust in
`lib/resources/<table>.dart`. Everything else about the resource stays
generated.

The renderer is where the fork lives. This is the host's own summary of the rule:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
/// Renders one field: an editable input inside a [BeakFormScope], otherwise
/// the read-only value from a [BeakRecordScope]; nothing outside both.
Widget _field(BuildContext context, BeakFieldBlock block) {
  final form = BeakFormScope.of(context);
  if (form != null) {
    return _fieldInput(form, block.column);
  }
  final scope = BeakRecordScope.of(context);
  if (scope == null) {
    return const SizedBox.shrink();
  }
  // ... render the read-only value ...
}
```

One layout, two surfaces. Write it once, wire it to both slots on the resource,
and the same tree serves the show page and the create/edit page.

## You may not need one

Before you write a layout, look at what you get without one. A resource with no
`detail` renders a derived show page: a headline card, then the remaining
fields, then a tab per to-many relationship. That is the same shape most
hand-written layouts end up with, so reach for `detail` when you want a
different arrangement, not to get the default back.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
/// The show-page layout: [detail] when declared, and otherwise the one
/// [model] implies — a headline card, the remaining fields, and a tab per
/// to-many relationship.
BeakBlock get effectiveDetail => detail ?? beakDefaultDetailLayout(model);
```

## The three blocks

### BeakFieldBlock

A single field: a label and the scoped record's value for one column.

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
const BeakFieldBlock(
  this.column, {
  this.label,
  this.layout = BeakFieldLayout.stacked,
  super.span,
});
```

`layout` chooses how label and value sit:

| `BeakFieldLayout` | Arrangement |
| --- | --- |
| `stacked` | label above the value (the readable default for narrow columns) |
| `inline` | label beside the value (a compact definition row) |

### BeakFieldGroupBlock

A responsive definition grid of several fields, so you do not write one
`BeakFieldBlock` per attribute. Each entry renders as a stacked label/value.

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_group_block.dart"
const BeakFieldGroupBlock(this.columns, {this.columnCount = 2, super.span});
```

### BeakRelationBlock

The scoped record's related rows, inline in its layout, rendered through the
shared relation manager (a table of the related records with attach/detach where
applicable).

```dart title="packages/beak_frontend/lib/src/blocks/beak_relation_block.dart"
const BeakRelationBlock(this.relationship, {this.title, super.span});
```

## One layout, wired to both slots

Here is the showcase's product layout. It uses all three blocks and is declared
`const`, because a block tree is pure configuration. `ProductColumns` and
`ProductRelations` are generated from the `Product` schema class, so every name
below is checked by the compiler.

```dart title="examples/superdashboard/lib/panel/details/commerce_layouts.dart"
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
          // ... one tab per related list ...
        ],
      ),
    ),
  ],
);
```

The same constant goes into two resource slots. A resource file takes the
generated `BeakResource` and returns a copy with the parts a person decided:

```dart title="examples/superdashboard/lib/resources/products.dart"
/// The products resource, with the parts Beak cannot derive.
///
/// Its model, label, icon and section still come from the schema class and
/// `beak.yaml`; this adds what a person decided.
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  filters: [
    const BeakSelectFilter(column: ProductColumns.status, label: 'Status'),
    const BeakTextFilter(column: ProductColumns.name, label: 'Name'),
  ],
);
```

!!! note "What just happened"
    - The file is named after the table (`products.dart`) and declares one
      function. Nothing registers it: `beak prepare` finds it and calls it with
      the resource it generated. `beak eject resource products` writes the
      starter.
    - `detail: productLayout` renders the tree inside a `BeakRecordScope`, so
      every `BeakFieldBlock` shows a formatted, read-only value.
    - `formLayout: productLayout` renders the *same* tree inside a
      `BeakFormScope`, so every field becomes an input. The `BeakFieldGroupBlock`
      of `name`, `sku`, `status`, `price` becomes four inputs; the image field
      becomes an upload field; and `ProductColumns.categoryId` becomes a
      belongs-to picker, because the form scope knows that column is a foreign key.
    - `model`, `icon`, `label` and `section` are not mentioned, so they stay
      what the schema class and `beak.yaml` produced. Drop the `filters` line
      too and Beak derives the filter bar from the columns marked
      `@Column(filterable: true)`.

The layout constant itself is an ordinary top-level `const`, so it can live
anywhere the resource file can import. The showcase keeps its commerce layouts
together in `lib/panel/details/commerce_layouts.dart`; a smaller project often
puts the tree straight in `lib/resources/<table>.dart`.

## How relations behave in each scope

`BeakRelationBlock` is the one record block whose two modes differ in more than
formatting, because a to-many relation needs a saved parent to attach to. In a
`BeakRecordScope` it always renders the relation manager for the scoped record.
In a `BeakFormScope` it renders the manager only once the record exists:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
final Object? editingId = form.recordId;
if (editingId == null) {
  return OiLabel.caption(
    'Save first to manage ${block.relationship.label.toLowerCase()}.',
  );
}
```

So on a create form, the Variants tab shows "Save first to manage variants.";
on an edit form or the detail page, it shows the manageable table. That is by
design: there is no parent id to attach children to until the first save.

!!! tip "Fields the form did not register"
    A field block for a column the form never registered (the id, or a
    detail-only column) renders nothing on the form surface. Put id and computed
    columns in your layout freely; they show on the detail and quietly disappear
    on the form.

## Continue reading

- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) how the record scope is set up and what the default detail looks like.
- [Forms](../panel/forms.md) the form scope, field inputs, and the belongs-to picker these blocks render into.
- [Relationships](../models/relationships.md) the `BeakRelationship` a `BeakRelationBlock` renders.
- [Rendering per surface](../concepts/rendering-per-surface.md) why one column definition can format itself for the table, the detail, and the form.
