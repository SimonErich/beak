# Add a resource

> Declare a schema and register its screen configuration.

Add a schema below `lib/`, run `beak prepare`, review its migration and register a `BeakResource` in the panel. Place screen definitions beside the resource. The category resource shows a complete configuration.

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

## Continue reading

- [Related guide](../panel/resources.md)
- [All recipes](index.md)
