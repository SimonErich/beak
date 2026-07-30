---
title: An enum badge column
description: A select in the form and a coloured badge everywhere else, from one field.
---

# An enum badge column

Declare the field as your enum and Beak renders a select in the form and a
badge everywhere else. `@Badges` maps each value to a colour, and the badge
shows up in the table, the detail row and the filter without any per-surface
code:

```dart title="examples/store/lib/models/product.dart"
  /// Lifecycle state, rendered as a coloured badge.
  @Column(filterable: true)
  @Badges({
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  })
  late final ProductStatus status;
```

## Continue reading

- [Column types](../models/column-types.md)
