---
title: Blocks and charts
description: Compose custom page content from typed descriptions.
type: index
audience: [beginner, expert]
status: stable
---

# Blocks and charts

Blocks describe custom page content. `BeakBlockHost` renders the sealed block tree and propagates record context. Layout, content, data and module blocks remain available alongside configured forms. Use form layout nodes for editing persisted drafts.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_block.dart"
```

## Which page to read

| You want to… | Read | For |
| --- | --- | --- |
| Arrange custom pages with columns, grids, cards and tabs | [Layout blocks](layout-blocks.md) | Guide for beginners |
| Render text, markdown, media, alerts, badges, progress and ratings without data plumbing | [Content blocks](content-blocks.md) | Guide for beginners |
| Load aggregates and scoped tables on custom pages | [Data blocks](data-blocks.md) | Guide for beginners and experts |
| Declare authorized aggregates that stay independent of the current table page | [Population summaries](summaries.md) | Guide for experts |
| Read formatted fields and relationships from a record context | [Record blocks](record-blocks.md) | Guide for experts |
| Configure specialized calendar, kanban, inbox and file views | [Module blocks](module-blocks.md) | Guide for experts |
| Supply typed chart data and presentation for the chart families, including heatmap, bubble and candlestick | [Charts](charts.md) | Guide for beginners and experts |
| Configure data maps and tile maps inside custom screens | [Maps](maps.md) | Guide for experts |

## Continue reading

- [Layout blocks](layout-blocks.md): Arrange custom pages with columns, grids, cards and tabs.
- [Content blocks](content-blocks.md): Render text, markdown, media, alerts, badges, progress and ratings without data plumbing.
- [Data blocks](data-blocks.md): Load aggregates and scoped tables on custom pages.
