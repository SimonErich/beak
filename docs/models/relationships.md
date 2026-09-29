---
title: Relationships
description: Declare typed connections and ownership for pickers and nested editing.
type: guide
audience: [beginner, expert]
status: draft
---

# Relationships

Use `@BelongsTo`, `@HasMany` and `@BelongsToMany` for to-one, owned or referenced collections, and pivot-backed connections. The generator resolves foreign-key identity types and emits typed relationship descriptors. Configure inverse relationships and deletion behavior deliberately.

A generated to-one descriptor provides `.inputCombobox()` and related field paths. A to-many descriptor provides `.tableForm()` and relation filters. Owned nested rows stay in the parent's draft until Save. Detaching a shared record is different from deleting an owned child; editor options and model ownership determine what is permitted.

`BeakExists` and `BeakFieldMatch` express eligibility. The picker infers filters and prerequisites from these rules, invalidates stale selections after a dependency changes, and supplies matching values when staging related creation. The backend checks eligibility independently.

Queries request eager relation loads explicitly. Related table and global-search paths use the same typed descriptors. See the order item and parent order models for ownership and optional product references.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order.dart"
```

## Continue reading

- [Forms](../forms/form-screens.md)
- [Validation](validation.md)
