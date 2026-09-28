---
title: The registry
description: Resolve typed models for resources and related records.
---

# The registry

`BeakModelRegistry` indexes models by table and rejects duplicate registrations. Registration checks model defaults and behavior metadata. The panel builds its registry from resources and recursively discovered related models; a related model does not need a navigation entry.

The generated server registry uses the same schemas. Custom hosts and tests may construct a registry explicitly. Use `byTableOrThrow` when absence is a configuration error. Each mounted panel has its own dependency scope, so embedded panels do not share accidental global state.

```dart title="examples/clean_beak_config/lib/beak/registry.g.dart"
--8<-- "examples/clean_beak_config/lib/beak/registry.g.dart"
```

## Continue reading

- [Declarative resources](../concepts/declarative-resources.md)
- [Custom screens](../extending/custom-screens-and-pages.md)
