# What is Beak?

> Build Dart and Flutter admin interfaces from shared model and screen configuration.

Beak is a Dart and Flutter framework for model-driven admin panels. Schemas define types, relationships, validation and behavior. Resources define navigation, search and screens. Layouts arrange fields while the framework handles drafts, queries, persistence and refresh.

The default backend uses Shelf and Worm; data-source interfaces support other integrations. The frontend uses Obers UI. Custom screens and widgets remain available when a task needs more than generated CRUD.

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

- [Quickstart](quickstart.md)
- [Declarative resources](../concepts/declarative-resources.md)
