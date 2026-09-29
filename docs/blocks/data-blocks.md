---
title: Data blocks
description: Load aggregates and scoped tables on custom pages.
type: guide
audience: [beginner, expert]
status: draft
---

# Data blocks

Data blocks resolve the panel source and provide their own loading, empty and error states. Metrics use aggregate specifications; tables use models and query specifications. Use typed filters for permanent scopes and subscribe through the panel mutation source for custom loaders.

```dart title="packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
```

## Continue reading

- [Block reference](../reference/blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
