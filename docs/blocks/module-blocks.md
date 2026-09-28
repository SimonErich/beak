---
title: Module blocks
description: Configure specialized calendar, kanban, inbox and file views.
---

# Module blocks

Module blocks expose typed field mappings and callbacks for task-specific interfaces. Calendar, kanban, inbox, chat, timeline and file-manager blocks can be placed inside custom screens. Their callbacks are extension points; application business mutations should still pass the authoritative model or graph boundary.

```dart title="packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart"
```

## Continue reading

- [Block reference](../reference/blocks-index.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
