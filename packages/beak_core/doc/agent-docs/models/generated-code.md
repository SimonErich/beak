# Generated code

> Understand generated fields, record readers and preserved authored files.

Run `beak prepare` after editing a schema. It discovers resource schemas under `lib/`, emits adjacent `.beak.dart` parts and updates the registry, panel defaults and server wiring. Generated files are committed; edit their schemas instead of their output.

Generated models expose typed scalar and relationship fields, query helpers and record readers. The `fields` namespace always contains every field. Direct shortcuts are omitted for names that collide with model members. Static schema `validationRules` and `behavior` getters are forwarded to the model.

The generator also proposes missing migrations. Existing migrations are preserved as upgrade history, and authored entrypoints and overrides remain application code. Review and apply database migrations explicitly. `beak doctor` detects stale generation and inconsistent wiring.

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

- [Defining models](defining-models.md)
- [CLI commands](../reference/cli-commands.md)
