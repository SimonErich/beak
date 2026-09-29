---
title: The type-safety promise
description: Use generated fields and typed values across queries and drafts.
type: concept
audience: [beginner, expert, agent]
status: draft
---

# The type-safety promise

Generated field descriptors preserve the value type and owning model. They build queries, read records and edit drafts through the same vocabulary. Related paths preserve both the root model and the traversal. The universal `fields` namespace handles names that cannot have direct shortcuts.

Wire records are decoded at transport boundaries into `BeakValue` types. Model registration and validation reject incompatible configuration. Custom adapters and widgets should use those typed boundaries rather than copying untyped maps into application logic.

## Continue reading

- [Generated code](../models/generated-code.md)
- [Custom data sources](../extending/custom-data-sources.md)
