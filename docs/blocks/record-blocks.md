---
title: Record blocks
description: Read formatted fields and relationships from a record context.
type: guide
audience: [expert]
status: draft
---

# Record blocks

`BeakFieldBlock` displays one typed field. Field groups arrange several values, and relation blocks display included relationships. Record blocks are read-only presentation. For an editable custom area, use `BeakFormWidget` and the supplied `BeakDraftScope` inside a configured form.

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
```

## Continue reading

- [Block reference](../reference/blocks.md)
- [Custom widgets](../extending/custom-blocks-and-widgets.md)
