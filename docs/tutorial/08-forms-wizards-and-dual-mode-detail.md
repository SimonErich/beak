---
title: 8. Forms, wizards, and dual-mode detail
description: Group form fields into conditional sections, turn a long create form into a stepped wizard, and build one block layout that renders both the show page and the edit form.
---

# 8. Forms, wizards, and dual-mode detail

By the end of this chapter the roastery has forms that fit the work. You will group
a product form into sections that appear and disappear as the user types, turn
product creation into a stepped wizard, and give orders a bespoke detail page whose
exact layout is reused, unchanged, as the edit form.

Every column you defined back in chapter 4 already renders a correct field with
client validation mirroring the server. This chapter is about arranging those
fields, not re-declaring them.

## Sections with conditional visibility

Beak's generated form renders every form-context column in one scroll. For a longer
model you can split it into titled sections, and gate a section behind a predicate
so it only appears when it is relevant. Sections both subset and order the fields;
a column in no section carries no field.

`BeakDataForm` is the widget the resource form is built from, and it takes the
`sections` directly. Reach for it when a generated form needs more shape than the
resource config gives it. Here is a product form for the store: the basics are
always visible, but you only ask for price and stock once the product is set to go
live.

```dart
BeakDataForm(
  model: const ProductModel(),
  dataSource: dataSource,
  sections: [
    const BeakFormSection(
      title: 'Basics',
      columns: [
        ProductColumns.name,
        ProductColumns.description,
        ProductColumns.status,
      ],
    ),
    BeakFormSection(
      title: 'Catalog',
      columns: const [
        ProductColumns.price,
        ProductColumns.stock,
        ProductColumns.categoryId,
      ],
      // Only ask for price and stock once the product is published.
      visibleWhen: (values) =>
          values.valueOf<ProductStatus>(ProductColumns.status) ==
          ProductStatus.published,
    ),
  ],
)
```

The `visibleWhen` predicate reads other fields through `values.valueOf<T>(column)`,
addressed by the same typed constant, returning the typed value (here a
`ProductStatus`, the enum from chapter 4). Because the read is tracked, the section
re-evaluates the moment the status field changes: set the product to Published and
the Catalog section slides in, no rebuild code on your side.

!!! tip "Predicates read, they do not write"
    A `visibleWhen` predicate is a pure function of the current values. It decides
    whether a whole section shows. Field-level validation still lives on the column
    rules you declared once.

## A stepped wizard for creating a product

A wizard is the same set of fields paced behind a step indicator, one page at a
time, with per-step validation gating advance. When a resource sets `formSteps`,
its create and edit routes render as a wizard instead of one scrolling form.

Add these steps to your store, then wire them onto the Products resource. A
`BeakFormStep` is a titled group of columns with optional supporting copy:

```dart
/// A three-step create/edit wizard for products, grouped by what each step asks for.
const List<BeakFormStep> productFormSteps = [
  BeakFormStep(
    title: 'Details',
    subtitle: 'Name & description',
    icon: OiIcons.fileText,
    description:
        'Give the product a clear name and a short description so shoppers '
        'know what they are buying. The name is required.',
    columns: [ProductColumns.name, ProductColumns.description],
  ),
  BeakFormStep(
    title: 'Pricing',
    subtitle: 'Price & stock',
    icon: OiIcons.euro,
    description:
        'Set the sale price in euros and how many units are in stock.',
    columns: [ProductColumns.price, ProductColumns.stock],
  ),
  BeakFormStep(
    title: 'Catalog',
    subtitle: 'Status, category & photo',
    icon: OiIcons.tag,
    description:
        'Choose the lifecycle status, file the product under a category, and '
        'add a photo.',
    columns: [ProductColumns.status, ProductColumns.categoryId, ProductColumns.image],
  ),
];
```

Then set `formSteps` on the Products resource in `buildReferencePanelConfig` (this
is the resource you first declared in chapter 3 and grew with filters and actions in
chapter 6):

```dart
BeakResource(
  model: ProductModel(),
  icon: BeakIconToken(OiIcons.package),
  formSteps: productFormSteps,
  // ...your existing filters and recordActions stay as they are.
)
```

Now "New product" opens a wizard. Each step shows its `description` as a banner and
its own fields; advancing runs that step's rules and blocks with a notice if the
required fields are not filled; the final step submits. The category field renders
as a belongs-to picker and the photo field as an upload, because the columns still
carry everything Beak needs.

## One layout for show and for edit

The most useful trick in the panel: a single block tree that renders read-only
values on the show page and editable inputs on the edit form. The record blocks are
dual-mode. Inside a record scope they format values (badges, dates, images,
relations); inside a form scope the same blocks render inputs. You describe the
layout once and hand it to both `detail` and `formLayout`.

Give the store's orders a bespoke layout. Add it to your store:

```dart
/// The order layout, used for both the show page and the create/edit form:
/// a headline strip, a customer card, and the line items inline.
const BeakBlock storeOrderLayout = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Order',
      child: BeakFieldGroupBlock([
        OrderColumns.reference,
        OrderColumns.total,
        OrderColumns.placedAt,
      ], columnCount: 3),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Customer',
          child: BeakFieldGroupBlock([OrderColumns.userId]),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Line items',
          child: BeakRelationBlock(OrderRelations.items),
        ),
      ],
    ),
  ],
);
```

A `BeakFieldGroupBlock` is a compact definition grid of several fields; a
`BeakRelationBlock` renders a relationship inline (here the order's `items`
has-many, from chapter 4). Wire the same tree to both slots on the Orders resource:

```dart
BeakResource(
  model: OrderModel(),
  icon: BeakIconToken(OiIcons.shoppingCart),
  detail: storeOrderLayout,
  formLayout: storeOrderLayout,
)
```

Open an order and you get your cards and grid, filled with formatted values and the
line items listed below. Hit Edit and the identical layout comes back, the fields
now inputs, the line items now an attach/detach manager. One description, two
surfaces, and they can never drift apart because they are the same tree.

!!! note "Why `userId` and not a name"
    The customer card shows `OrderColumns.userId`, the foreign key. On the form it
    becomes a belongs-to picker (search a customer by name); on the show page it
    resolves to the related record's display value. The column carries the behaviour
    into whichever surface renders it.

## Run it

With the backend from chapter 3 up on port 8080, launch the panel:

```bash
cd examples/store
flutter run -d chrome
```

In Chrome, open Products and click "New product": the create form is now a
three-step wizard (Details, Pricing, Catalog) with a step indicator, per-step
validation, and a Create button on the last step. Open Orders and pick any seeded
order: it renders through your custom layout (an Order strip, a Customer card, and
the Line items beside it). Click Edit and the same layout returns with editable
fields.

!!! note "What just happened"
    - `BeakFormSection` groups and orders fields; a `visibleWhen` predicate shows or
      hides a section based on other fields, tracked so it updates as you type.
    - `formSteps` on a resource renders create and edit as a validated wizard.
    - The record blocks (`BeakFieldGroupBlock`, `BeakFieldBlock`, `BeakRelationBlock`)
      are dual-mode: pass one block tree to both `detail` and `formLayout` and it
      renders values on show and inputs on edit.

## Continue reading

- [9. Auth, theming, and polish](09-auth-theming-and-polish.md) guard the shell and make it yours.
- [Multi-step forms](../panel/multi-step-forms.md) wizards, step validation, and pacing.
- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) one layout on two surfaces, in depth.
- [Record blocks](../blocks/record-blocks.md) field, field-group, and relation blocks.
