# Block system internals

> See how one sealed block union and a single host render pages, view modes, detail views and forms.

After this page you can explain how the block renderer dispatches each block, how a grid child claims its span, and how record blocks obtain their data.

Every non-CRUD surface in Beak is a tree of blocks. A custom page's body, a resource's alternate view mode, an overlay's content, a detail layout, a form layout: all of them are `BeakBlock` values, and all of them are rendered by one widget, `BeakBlockHost`. The union is sealed and the host's switch is exhaustive, so the block system cannot drift out of sync with itself.

The union is defined in `packages/beak_frontend/lib/src/blocks/beak_block.dart`; the renderer is `packages/beak_frontend/lib/src/blocks/beak_block_host.dart`.

## One sealed union

`BeakBlock` is a sealed base with a single shared field, an optional `span` used for grid tracks or as a relative width in an expanded row. Every concrete block, roughly fifty of them, extends it as a part-file of the same library (sealed types must live in one library).

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
@immutable
sealed class BeakBlock {
  /// Creates a block, optionally sized by [span] inside grid parents.
  const BeakBlock({this.span});

  /// Grid tracks occupied inside a [BeakGridBlock]. An expanded [BeakRowBlock]
  /// uses its columns as relative width weights instead; ignored elsewhere.
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

The grid is where `BeakSpan` earns its place on the base class. A `BeakGridBlock` renders as an `OiGrid`. Fixed grids use `LayoutBuilder` to calculate each child's width from the available width, gaps, and column span. If any child falls below `minChildWidthInPixels` (240 by default), the grid uses one track. The existing spans clamp to that track, preserving reading order and natural card heights. Setting the minimum to zero disables this fallback; auto-fitting grids retain their explicit `minColumnWidthInPixels` behavior.

Each child is wrapped by `_spanned`, which reads the child's `span` and, when present, places it in an `OiSpan` covering that many column and row tracks:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
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

## Record presentation and configured forms

`BeakFieldBlock` and `BeakFieldGroupBlock` display values from the nearest
`BeakRecordScope`. The host delegates formatting to `renderBeakCell`, the same
renderer used by table cells. Without a record scope, these blocks render an
empty widget. `BeakRelationBlock` uses the scoped record's identity and the
panel's data source to render a relationship manager; eagerly loaded rows can
supply its initial data.

Configured forms use a separate typed layout tree: `BeakCard`, `BeakColumns`,
`BeakSection`, `BeakTabs`, field inputs and relationship editors. A
`BeakFormScreen` can serve read, create and edit roles with this one layout.
`BeakFormSections` projects reusable sections into a stacked form, tabs or
wizard steps. The form renderer selects values or inputs according to the
current mode and shares the column formatting contract with record blocks.

A custom form widget reads `BeakDraftScope.of(context)` for its draft and
inherited enabled/read-only state. Changes made through that draft participate
in the configured form's validation, review and graph save. A `BeakWidgetBlock`
on a custom page instead supplies ordinary presentation under the panel's data
and formatting scopes.

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
- **Shared formatting.** Record blocks and configured forms consume the same column metadata and formatting policy, while each keeps an appropriate presentation or draft scope.

## Continue reading

- [The block system](../concepts/the-block-system.md) the same idea at concept level, with the three consumers.
- [Blocks overview](../blocks/index.md) the full catalog of block types.
- [Record blocks](../blocks/record-blocks.md) read-only field and group blocks, and relationship presentation.
- [Detail views and dual-mode blocks](../forms/detail-views.md) using a configured form for read and edit roles.
- [The widget escape hatch](../extending/custom-blocks-and-widgets.md) dropping to a raw widget when a block will not do.
