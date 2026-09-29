---
title: Dashboards
description: Combine live queries, aggregates and custom widgets on a page.
type: guide
audience: [beginner]
status: draft
---

# Dashboards

A dashboard is a `BeakScreen` with declarative blocks. `BeakMetricBlock` loads an aggregate, `BeakTableBlock` shows a scoped list, and layout blocks arrange them. Blocks use the panel source, share model formatting and respond to mutation notifications.

The page frame supplies the heading, gutters and scrolling without adding a
background around your cards. Each card or chart owns its surface. A table's
`baseFilter` is permanent: it constrains the first request, pagination totals,
search, sorting, user-filter changes and refreshes after confirmed writes.

The shop overview combines fulfillment and stock counts, a custom receivables widget and compact operational tables. The custom widget demonstrates exact money formatting, loading, a retryable error state and refresh after invoice changes.

```dart title="examples/clean_beak_config/lib/overview.dart"
--8<-- "examples/clean_beak_config/lib/overview.dart"
```

## Continue reading

- [Data blocks](../blocks/data-blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
