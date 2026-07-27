---
title: The block system
description: One sealed BeakBlock union and one exhaustive BeakBlockHost renderer power custom pages, view modes, detail layouts, forms, and overlays.
---

# The block system

Everything in Beak that is not a plain CRUD table is a tree of blocks. After this
page you know what a block is, why there is exactly one renderer for all of them,
and how the same record blocks flip between read-only and editable depending on
where you drop them.

## A block is const configuration

A `BeakBlock` is a declarative content node. It holds data, not widget code: a
title string, a list of children, a grid span. It never builds a widget itself
and never carries a callback, except where an interaction is the whole point of
the block (and the one documented raw-widget escape hatch).

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
@immutable
sealed class BeakBlock {
  /// Creates a block, optionally sized by [span] inside grid parents.
  const BeakBlock({this.span});

  /// How many grid tracks this block occupies when it is a direct child
  /// of a [BeakGridBlock]; ignored elsewhere.
  final BeakSpan? span;
}
```

Because blocks are pure `const` values, a layout is data you can write inline,
pass around, and compare. Here is a page body built entirely from block
constructors:

```dart
const body = BeakColumnBlock(
  children: [
    BeakTextBlock('Welcome back', variant: BeakTextVariant.h1),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 6),
          child: BeakTextBlock('Half width'),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 6),
          child: BeakTextBlock('Other half'),
        ),
      ],
    ),
  ],
);
```

## One renderer, exhaustive

The sealed union has around fifty variants, and exactly one thing renders them:
`BeakBlockHost`. Its `build` is a single `switch` over the union, so every block
type maps to an obers_ui widget in one place.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
class BeakBlockHost extends StatelessWidget {
  /// Creates a host rendering [block].
  const BeakBlockHost({required this.block, super.key});

  /// The block tree to render.
  final BeakBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    final BeakColumnBlock column => _column(context, column),
    final BeakRowBlock row => _row(context, row),
    final BeakGridBlock grid => _grid(context, grid),
    final BeakCardBlock card => _card(card),
    // ... one arm per block type
    final BeakMarkdownBlock markdown => OiMarkdown(data: markdown.source),
    // ... divider, spacer
    final BeakWidgetBlock widget => Builder(builder: widget.builder),
  };
```

The switch is exhaustive over the sealed union, so adding a block type without
teaching the host about it is a compile error. That is the guarantee that keeps
the block catalogue honest: a block cannot exist that nothing knows how to draw.
Container blocks recurse (a card renders `BeakBlockHost(block: block.child)`), so
the whole tree renders from the one host.

## Where blocks are used

The same block descriptors drive several surfaces. Learn the union once, and you
can build any of these:

| Surface | What it renders | Where you set it |
| --- | --- | --- |
| Custom screens | a full page body | `BeakScreen.body`, from a file in `lib/screens/` |
| Resource view modes | an alternate view of a list | `viewModes` in `lib/resources/<table>.dart` |
| Detail layouts | a record's read-only page | `detail` in `lib/resources/<table>.dart` |
| Form layouts | a create/edit form | `formLayout` in `lib/resources/<table>.dart` |
| Overlay bodies | a modal or sheet's content | the overlay APIs |
| Dashboards | KPI, chart, and table tiles | `lib/dashboard.dart` |

One host renders all of them, so a `BeakCardBlock` on a dashboard and a
`BeakCardBlock` in an overlay are the exact same code path.

The store sets two of them from one tree. `beakResource` takes the resource Beak
generated and returns the copy it wants:

```dart title="examples/store/lib/resources/products.dart"
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  detail: productLayout,
  formLayout: productLayout,
  // ... actions and view modes
);
```

## You get a layout without writing one

A resource that declares no `detail` is not left with a bare field list. The
show page falls back to the layout the model implies:

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
/// The show-page layout: [detail] when declared, and otherwise the one
/// [model] implies — a headline card, the remaining fields, and a tab per
/// to-many relationship.
BeakBlock get effectiveDetail => detail ?? beakDefaultDetailLayout(model);
```

`beakDefaultDetailLayout` builds an ordinary block tree out of the same three
record blocks you would have used: a `BeakCardBlock` holding a
`BeakFieldGroupBlock` of the first few fields, a grid for the rest, and a
`BeakTabsBlock` with one `BeakRelationBlock` per to-many relationship. It is
derived rather than generated, so adding a column changes the page with no file
to regenerate. Write a `detail` when you want a different shape, not to get one
at all.

## Grid placement with BeakSpan

A block that sits directly inside a `BeakGridBlock` can claim more than one
track. That is what `BeakSpan` is for.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
@immutable
final class BeakSpan {
  /// Creates a span covering [columns] × [rows] grid tracks.
  const BeakSpan({this.columns = 1, this.rows = 1})
    : assert(columns >= 1, 'columns must be >= 1'),
      assert(rows >= 1, 'rows must be >= 1');

  /// Number of grid columns covered.
  final int columns;

  /// Number of grid rows covered.
  final int rows;
}
```

The host reads `child.span` when it lays out a grid and wraps the child in the
obers_ui span; outside a grid the span is ignored.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
/// Wraps a grid child in its [BeakBlock.span] placement, when declared.
Widget _spanned(BeakBlock child) {
  final host = BeakBlockHost(block: child);
  final span = child.span;
  if (span == null) {
    return host;
  }
  return OiSpan(
    data: OiSpanData(
      columnSpan: OiResponsive<int>(span.columns),
      rowSpan: OiResponsive<int>(span.rows),
    ),
    child: host,
  );
}
```

## Dual-mode record blocks

Three blocks are special: `BeakFieldBlock`, `BeakFieldGroupBlock`, and
`BeakRelationBlock`. They are record-bound, and they render *differently
depending on where the tree is mounted*. Drop the same layout into a detail page
and it shows read-only values; drop it into a form and it shows editable inputs.
You write the layout once and get both surfaces.

The switch is not on the block, it is on the scope. The host looks for a form
scope first (which means "we are editing"), then a record scope (which means "we
are displaying"), and if it finds neither it renders nothing rather than
throwing.

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
  final String label = block.label ?? block.column.label;
  final Widget value = renderBeakCell(
    context,
    column: block.column,
    record: scope.record,
    renderContext: BeakContext.detail,
  );
  // ... stacked or inline label + value
}
```

The two scopes are ordinary inherited widgets. `BeakRecordScope` carries the one
loaded record down to the field leaves so a detail layout can be a plain `const`
block tree.

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
/// Carries the record a detail layout is rendering down to the record-bound
/// blocks (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`), so a
/// resource's `detail` layout can be a plain, `const` block tree while its
/// field leaves still resolve their values from the one loaded record.
class BeakRecordScope extends InheritedWidget {
```

`BeakFormScope` carries the form controller and upload wiring instead, so the
same leaves bind to editable inputs.

```dart title="packages/beak_frontend/lib/src/form/beak_form_scope.dart"
/// This is what lets one structured layout drive both the show page and the
/// create/edit form: the blocks look for a form scope first (→ inputs), then a
/// record scope (→ values). A `BeakDataForm` with a `layout` installs one of
/// these around the block host.
class BeakFormScope extends InheritedWidget {
```

A relation block honors the same rule, with one extra guard: in a form, a
to-many relation can only be managed once the parent record exists, because there
is no id to attach children to yet.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
final Object? editingId = form.recordId;
if (editingId == null) {
  return OiLabel.caption(
    'Save first to manage ${block.relationship.label.toLowerCase()}.',
  );
}
```

!!! note "What just happened"
    - Record blocks do not know whether they are being read or edited.
    - `BeakBlockHost` decides from the nearest scope: form scope wins (inputs),
      then record scope (values), then nothing.
    - One block tree serves both the detail page and the create/edit form.

## The widget escape hatch

When no block fits, `BeakWidgetBlock` carries a `WidgetBuilder` and the host
renders it through a `Builder`. It is the one block that holds widget code on
purpose, for the rare thing the catalogue does not cover.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
final BeakWidgetBlock widget => Builder(builder: widget.builder),
```

Reach for it sparingly. Most of what you want is already a block, and a real
block keeps its data `const` and comparable while a raw widget does not.

## Continue reading

- [Blocks](../blocks/index.md) the full catalogue, grouped by category.
- [Record blocks](../blocks/record-blocks.md) the dual-mode field and relation
  blocks in detail.
- [Layout blocks](../blocks/layout-blocks.md) columns, rows, grids, and spans.
- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) how a
  resource wires a layout into both its show page and its form.
- [Custom screens](../panel/custom-screens.md) mounting a block tree as a full
  page.
- [The widget escape hatch](../blocks/the-widget-escape-hatch.md) when to drop to
  a raw widget, and how.
