---
title: A belongs-to picker
description: A searchable picker and a linked label, generated from one annotated field.
---

# A belongs-to picker

Point a field at another schema class and annotate it `@BelongsTo`. Beak
generates the foreign-key column, both sides of the relationship, a searchable
picker in the form and a linked label in the table and detail:

```dart title="examples/store/lib/models/product.dart"
  /// The category this product is filed under.
  @BelongsTo(onDelete: BeakOnDelete.setNull)
  late final Category? category;
```

The picker searches the related model's display column by default. When people
look a record up by something else, widen it with `searchOn`, and rename the
relationship with `label` (from the showcase app):

```dart title="examples/superdashboard/lib/models/invoices/invoice.dart"
  /// The billed user.
  @BelongsTo(label: 'Bill to', searchOn: ['name', 'email'])
  late final User? user;
```

## Continue reading

- [Relationships](../models/relationships.md)
- [Forms](../panel/forms.md)
