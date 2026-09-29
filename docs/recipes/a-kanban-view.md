---
title: A kanban view
description: Map model fields to a specialized workflow board.
type: recipe
audience: [beginner, expert, agent]
status: draft
---

# A kanban view

Place a `BeakKanbanBlock` on a custom screen and configure its model, grouping fields and callbacks. Use shared model actions for state transitions so drag interactions obey the same rules as forms. The block contract is shown below.

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
```

## Continue reading

- [Related guide](../panel/actions.md)
- [All recipes](index.md)
