# Your first resource

> Define a shared schema and register its presentation in a panel.

A schema describes stored facts. A resource describes navigation and screens. The panel discovers the related models and supplies loading, validation and persistence.

## Read a schema

This category owns reusable attribute definitions. Products refer to the category through their own belongs-to relationship. The annotations describe relationships and their deletion behavior; the generated part supplies typed fields and record readers.

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

Run `beak prepare` after changing a schema. Commit the generated `.beak.dart` files and review new migrations before applying them. You never edit a generated model to add application behavior: declare it on the schema.

## Register presentation

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/category.dart';
import 'models/category_attribute.dart';
import 'screens/category_form.dart';

/// Catalog organization and reusable attribute definitions.
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        model: const CategoryModel(),
        title: 'Categories',
        icon: const BeakIconToken(OiIcons.folderTree),
        navigationGroup: 'Catalog',
        navigationRank: 5,
        globalSearchSources: [
          CategoryModel.name,
          CategoryModel.description,
          CategoryModel.attributes.search(CategoryAttributeModel.name),
        ],
        filters: [CategoryModel.name.textFilter()],
        screens: [
          BeakTableScreen(
            fields: [CategoryModel.name, CategoryModel.description],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: categoryForm(),
          ),
        ],
      );
}
```

The resource inherits standard routes from its model. Configured screens replace only their declared route roles. Referenced models are registered even when they have no sidebar entry.

`lib/main.dart` supplies resources to `BeakPanel`. A generated project can retain its generated default panel until it needs an authored layout; `beak prepare` preserves an authored entrypoint.

## Continue reading

- [Fields and validation](02-columns-and-validation.md)
- [Generated code](../models/generated-code.md)
