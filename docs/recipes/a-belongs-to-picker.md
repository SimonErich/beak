---
title: A belongs-to picker
description: Use shared eligibility rules for a dependent selection.
---

# A belongs-to picker

Place the generated to-one field with `.inputCombobox()`. Shared existence and matching rules supply query scopes, prerequisites and invalidation. The order model restricts a delivery profile to its selected customer; its wizard requires no separate picker state.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order.dart"
```

## Continue reading

- [Related guide](../models/relationships.md)
- [All recipes](index.md)
