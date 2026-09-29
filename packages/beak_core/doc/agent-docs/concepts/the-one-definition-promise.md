# The one-definition promise

> Reuse schema metadata without confusing presentation with authority.

A schema supplies field types, nullability, labels, constraints, relationships and behavior. Generated descriptors carry that information into forms, tables, filters, search and API validation. Resource and layout definitions select how those facts are presented.

Screen-specific labels, visibility and validators can refine a workflow. They do not become server invariants automatically. Put rules shared by every caller on the model, and enforce account access through backend policy. Beak's declarative boundary removes repeated plumbing while keeping those responsibilities explicit.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category_attribute.dart';
part 'category.beak.dart';

/// Catalog grouping with reusable attribute definitions.
@Resource()
final class Category extends BeakSchema {
  /// Category title.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Description shown to administrators.
  late final String? description;

  /// Attributes expected for products in this category.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<CategoryAttribute> attributes;
}
```

## Continue reading

- [Declarative resources](declarative-resources.md)
- [Custom screens](../panel/custom-screens.md)
