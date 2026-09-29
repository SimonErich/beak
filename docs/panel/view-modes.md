---
title: View modes
description: Keep shared model behavior while choosing a task-specific presentation.
type: guide
audience: [beginner, expert]
status: draft
---

# View modes

Standard resources use tables and configured read/edit forms. A resource can select different screens for list, create, read and edit roles without copying model rules or persistence code.

For a task-specific list, compose a `BeakScreen` from table, calendar, kanban or custom widget blocks. Each module declares its field mapping and interaction callbacks. Business transitions should call shared model actions or the same graph boundary as forms. Presenting a kanban board does not by itself authorize a status change.

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
```

## Continue reading

- [Custom screens](custom-screens.md)
- [Actions](actions.md)
