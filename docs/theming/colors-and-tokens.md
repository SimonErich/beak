---
title: Colors and tokens
description: Apply semantic colors consistently across built-in and custom content.
---

# Colors and tokens

Beak UI uses the Obers UI theme for surfaces, borders, text and state colors. Column badges can map enum values to Beak colors while custom widgets resolve tokens from context.

Keep status meaning consistent between tables and forms. Use text or icons as well as color for important distinctions. Semantic formatting remains independent of theme colors. The order schema demonstrates state labels and shared metadata.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order.dart"
```

## Continue reading

- [Theming basics](theming-basics.md)
- [Semantic fields](../models/semantic-fields.md)
