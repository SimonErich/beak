---
title: The one-definition promise
description: Reuse schema metadata without confusing presentation with authority.
---

# The one-definition promise

A schema supplies field types, nullability, labels, constraints, relationships and behavior. Generated descriptors carry that information into forms, tables, filters, search and API validation. Resource and layout definitions select how those facts are presented.

Screen-specific labels, visibility and validators can refine a workflow. They do not become server invariants automatically. Put rules shared by every caller on the model, and enforce account access through backend policy. Beak's declarative boundary removes repeated plumbing while keeping those responsibilities explicit.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart"
```

## Continue reading

- [Declarative resources](../concepts/declarative-resources.md)
- [Custom screens](../extending/custom-screens-and-pages.md)
