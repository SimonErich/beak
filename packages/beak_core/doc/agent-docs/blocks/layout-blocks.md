# Layout blocks

> Arrange custom pages with columns, grids, cards and tabs.

Layout blocks compose other blocks. Use columns and rows for flow, grids for responsive minimum widths, cards and sections for grouping, and tabs or accordions for alternate content. These are page composition primitives. Forms use `BeakCard`, `BeakColumns`, `BeakTabs` and `BeakWizardStep` so their validation and state remain connected.

`BeakRowBlock(expand: true)` fills the available width using each child's
`BeakSpan.columns` as a relative weight. For example, weights 5, 3 and 4 divide
1,000 pixels of content into 416.67, 250 and 333.33 pixels; gaps are deducted only
between the three actual children. The default minimum child width is 240 pixels,
so the same row stacks inside a narrow page region without relying on the whole
window's breakpoint. Set `minChildWidthInPixels` to change that threshold, or to
zero to retain proportions at every bounded width. Ordinary rows preserve their
children's intrinsic widths; unbounded expanded rows safely do the same.


Fixed `BeakGridBlock` layouts preserve their declared column spans while there
is room. When any child would become narrower than `minChildWidthInPixels`
(240 by default), the grid stacks its children at full width in reading order.
This uses the grid's available width, so an overview also adapts inside a narrow
desktop panel. Cards keep their own natural heights. Set
`minChildWidthInPixels: 0` to retain fixed tracks at every width, or choose a
different minimum for compact content. Grids configured with
`minColumnWidthInPixels` continue to auto-fit their tracks instead.

```dart title="packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
part of 'beak_block.dart';

/// Places its children on a column grid; each child's [BeakBlock.span]
/// decides how many tracks it covers.
///
/// Provide either a fixed [columns] count or a [minColumnWidthInPixels]
/// for an auto-fitting grid — not both. Renders onto `OiGrid` with
/// `OiSpan` placement. Fixed grids stack when their children would become
/// narrower than [minChildWidthInPixels].
final class BeakGridBlock extends BeakBlock {
  /// Creates a grid of [children].
  const BeakGridBlock({
    required this.children,
    this.columns,
    this.minColumnWidthInPixels,
    this.minChildWidthInPixels = 240,
    this.gapInPixels = 16,
    super.span,
  }) : assert(
         columns == null || minColumnWidthInPixels == null,
         'Provide either columns or minColumnWidthInPixels, not both.',
       ),
       assert(minChildWidthInPixels >= 0);

  /// The blocks to place, in reading order.
  final List<BeakBlock> children;

  /// Fixed number of grid columns, when set.
  final int? columns;

  /// Minimum column width for an auto-fitting grid, when set.
  final double? minColumnWidthInPixels;

  /// Minimum readable child width before a fixed grid stacks in one column.
  ///
  /// Uses available container width, declared spans, and gaps. Set to zero
  /// to retain fixed tracks at every width. Auto-fitting grids use
  /// [minColumnWidthInPixels] instead and ignore this setting.
  final double minChildWidthInPixels;

  /// Spacing between grid tracks.
  final double gapInPixels;
}
```

## Continue reading

- [Block reference](../reference/blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
