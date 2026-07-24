---
title: Block system internals
description: How one sealed BeakBlock union and a single exhaustive BeakBlockHost render custom pages, view modes, detail, and forms.
---

# Block system internals

After this page you can explain why a new block type is a compile error until every renderer handles it, how a grid child claims its span, and how the same block tree renders read-only values on a detail page and editable inputs in a form.

Every non-CRUD surface in Beak is a tree of blocks. A custom page's body, a resource's alternate view mode, an overlay's content, a detail layout, a form layout: all of them are `BeakBlock` values, and all of them are rendered by one widget, `BeakBlockHost`. The union is sealed and the host's switch is exhaustive, so the block system cannot drift out of sync with itself.

The union is defined in `packages/beak_frontend/lib/src/blocks/beak_block.dart`; the renderer is `packages/beak_frontend/lib/src/blocks/beak_block_host.dart`.

## One sealed union

`BeakBlock` is a sealed base with a single shared field, an optional `span` used when the block is a direct child of a grid. Every concrete block, roughly fifty of them, extends it as a part-file of the same library (sealed types must live in one library).

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

Blocks are pure `const` configuration. They carry no widget code and no callbacks, except where an interaction is the whole point of the block (a wizard's `onComplete`) or the documented raw-widget escape hatch, `BeakWidgetBlock`. A block is data that describes what to show, not a widget that shows it.

## One exhaustive renderer

`BeakBlockHost` is a `StatelessWidget` whose `build` is a single `switch` over the union. Dart's exhaustiveness checking does the enforcement: because `BeakBlock` is sealed, a `switch` that misses a case does not compile, so adding a block type without teaching the host to render it breaks the build.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
@override
Widget build(BuildContext context) => switch (block) {
  final BeakColumnBlock column => _column(context, column),
  final BeakRowBlock row => _row(context, row),
  final BeakGridBlock grid => _grid(context, grid),
  final BeakCardBlock card => _card(card),
  final BeakSectionBlock section => _section(context, section),
  final BeakTabsBlock tabs => _BeakTabsHost(block: tabs),
  // ... roughly fifty arms, one per block type ...
  final BeakTextBlock text => _text(text),
  final BeakImageBlock image => _image(image),
  final BeakMarkdownBlock markdown => OiMarkdown(data: markdown.source),
  final BeakDividerBlock divider => _divider(divider),
  final BeakSpacerBlock spacer => SizedBox(height: spacer.heightInPixels),
  final BeakWidgetBlock widget => Builder(builder: widget.builder),
};
```

Every arm maps a block onto an obers_ui widget (`OiColumn`, `OiCard`, `OiTabs`, `OiMarkdown`, and friends). This is the only place in Beak that decides how a block looks, which is why the no-Material rule is enforceable: the mapping is centralized, so there is one surface to keep obers-only.

## Composition is recursion

Layout blocks hold child blocks, and the host renders each child by building another `BeakBlockHost`. A column block, for example, becomes an `OiColumn` whose children are hosts for its child blocks:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _column(BuildContext context, BeakColumnBlock block) => OiColumn(
  breakpoint: context.breakpoint,
  gap: OiResponsive<double>(block.gapInPixels),
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [for (final child in block.children) BeakBlockHost(block: child)],
);
```

The recursion terminates at leaf blocks (text, image, divider) that render a widget directly. A whole page is one root block whose tree the host walks top-down.

## Grids and spans

The grid is where `BeakSpan` earns its place on the base class. A `BeakGridBlock` renders as an `OiGrid`, and each child is wrapped by `_spanned`, which reads the child's `span` and, when present, places it in an `OiSpan` covering that many column and row tracks:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _grid(BuildContext context, BeakGridBlock block) => OiGrid(
  breakpoint: context.breakpoint,
  columns: switch (block.columns) {
    final int columns => OiResponsive<int>(columns),
    null => null,
  },
  minColumnWidth: switch (block.minColumnWidthInPixels) {
    final double width => OiResponsive<double>(width),
    null => null,
  },
  gap: OiResponsive<double>(block.gapInPixels),
  children: [for (final child in block.children) _spanned(child)],
);

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

The span lives on the child but is only honored by a grid parent; anywhere else it is ignored. That is why `span` is a field on the base class rather than a grid-only concept: a `BeakCardBlock` can declare `span: BeakSpan(columns: 6)` and be laid out correctly whether or not it happens to sit in a grid.

## Dual-mode: one layout, two surfaces

The block system's sharpest trick is that three blocks, `BeakFieldBlock`, `BeakFieldGroupBlock`, and `BeakRelationBlock`, render two entirely different things depending on where they sit. Inside a form they render editable inputs. Inside a detail page they render read-only values. The same `const` block tree drives both a resource's `detail` and its `formLayout`.

The host resolves this by looking for scopes, form first:

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
  // ... lay out label + value per block.layout ...
}
```

The two scopes are plain `InheritedWidget`s. A show page wraps its detail layout in a `BeakRecordScope` carrying the loaded record; a `BeakDataForm` with a layout wraps its block host in a `BeakFormScope` carrying the form controller.

```dart title="packages/beak_frontend/lib/src/detail/beak_record_scope.dart"
class BeakRecordScope extends InheritedWidget {
  const BeakRecordScope({
    required this.model,
    required this.record,
    required super.child,
    super.key,
  });

  static BeakRecordScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeakRecordScope>();
}
```

Three things keep this safe. Field blocks look for a form scope before a record scope, so a layout reused in both places always resolves to the right surface. A field outside both scopes renders `SizedBox.shrink()` rather than throwing, so a block composed in the wrong place degrades quietly instead of crashing. And in a form, a field the controller did not register (an id, a detail-only column) renders nothing:

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

A foreign-key column becomes a belongs-to picker; any other column becomes the type-mapped input; the read-only detail path runs `renderBeakCell` instead, the same cell renderer the data table uses. One layout, two surfaces, zero duplicated formatting.

## Where interaction state lives

Blocks are stateless data, so any interaction state belongs to the host, not the block. A tabbed block is the clearest case: the host renders it through a small private `HookWidget` that owns the selected-tab hook.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
class _BeakTabsHost extends HookWidget {
  const _BeakTabsHost({required this.block});

  final BeakTabsBlock block;

  @override
  Widget build(BuildContext context) {
    final selected = useState(block.initialIndex);
    final active = block.tabs[selected.value];
    return OiTabs(
      // ...
      selectedIndex: selected.value,
      onSelected: (index) => selected.value = index,
      content: BeakBlockHost(block: active.content),
    );
  }
}
```

The `BeakTabsBlock` stays a `const` description of tabs; the private host holds the "which tab is open" state with a hook. Data-bound blocks (KPI, chart, table) follow the same pattern in their own view widgets, fetching through the repository from DI. `StatefulWidget` never appears.

## Why this shape

- **Exhaustiveness over registration.** A sealed union plus a `switch` means the compiler, not a runtime lookup table, guarantees every block renders. There is no "unknown block type" branch to forget.
- **`const` config, not widgets.** Blocks are cheap immutable values, so a page layout is a literal you can define once and reuse. Rendering, state, and DI live in the host, keeping the block surface declarative.
- **Dual-mode by scope.** Because field blocks resolve their surface from an inherited scope rather than a mode flag, one layout can be the detail page and the form, which is how the showcase gives a resource identical structure on both.

## Continue reading

- [The block system](../concepts/the-block-system.md) the same idea at concept level, with the three consumers.
- [Blocks overview](../blocks/index.md) the full catalog of block types.
- [Record blocks](../blocks/record-blocks.md) the dual-mode field, group, and relation blocks.
- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) building a layout that serves both surfaces.
- [The widget escape hatch](../blocks/the-widget-escape-hatch.md) dropping to a raw widget when a block will not do.
