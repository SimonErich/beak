---
title: The block system
description: Separate custom page composition from draft-based forms.
type: concept
audience: [beginner, expert]
status: draft
---

# The block system

`BeakBlock` is the common description type for custom page content. `BeakBlockHost` dispatches the sealed hierarchy, provides record context and renders nested layouts. A `BeakWidgetBlock` admits an application widget where a specialized interaction is needed.

Blocks remain useful for dashboards, read views and specialized modules. Editing uses the configured-form runtime and form layout nodes, which carry field dependencies, relationship drafts and validation. A custom form node receives a draft scope; an independent custom widget receives normal Flutter context.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
```

## Continue reading

- [Block catalog](../blocks/index.md)
- [Forms](../forms/form-screens.md)
