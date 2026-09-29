---
title: Layout blocks
description: Arrange custom pages with columns, grids, cards and tabs.
type: guide
audience: [beginner]
status: draft
---

# Layout blocks

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
--8<-- "packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
```

## Continue reading

- [Block reference](../reference/blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
