---
title: Column basics
description: Control field labels, visibility, validation and queries from schema annotations.
---

# Column basics

A schema field supplies its Dart type and nullability. `@Column` adds a label, description, placeholder, defaults, validation rules and query capabilities. Non-nullable values become required.

`visibleOn` controls presentation surfaces. It does not protect a field from API access; server field policies do that. `searchable`, `sortable` and `filterable` expose the corresponding query operations. `indexed` and `unique` describe database requirements.

Input placement can override a label or add a screen-specific validator. Shared invariants belong on the schema. Keep annotations independent of Flutter widgets.

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart"
```

## Enum labels and badge colors

`@EnumLabels<OrderStatus>({OrderStatus.inKitchen: 'In kitchen'})` supplies human-readable labels for generated enum metadata. Forms, filters, tables and formatted exports share those labels. Unmapped values use their enum name; the stored and API values remain the original enum names.

Use `@Badges<OrderStatus>({...})` for semantic colors such as `BeakColor.warning` or `BeakColor.success`. The panel theme resolves those tokens, so the schema stays independent of Flutter colors. Placement-specific formatting such as `.currency(minorUnits: true)` can refine a view; shared units and money semantics belong on the schema when every surface needs them.

## Continue reading

- [Column types](column-types.md)
- [Validation](validation-rules.md)
