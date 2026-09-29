---
title: An enum badge column
description: Render a typed state with labels and colors.
type: recipe
audience: [beginner, expert, agent]
status: draft
---

# An enum badge column

Declare an enum field with a default when appropriate. `@Badges` can map enum values to presentation colors. Generated fields preserve enum typing in filters and forms. A model action should control workflow states that callers must not edit directly.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order.dart"
```

## Continue reading

- [Related guide](../models/fields.md)
- [All recipes](index.md)
