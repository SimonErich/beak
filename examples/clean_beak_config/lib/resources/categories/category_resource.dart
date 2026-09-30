import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/category.dart';
import 'models/category_attribute.dart';
import 'screens/category_form.dart';

/// Catalog organization and reusable attribute definitions.
// --8<-- [start:CategoryResource]
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        // --8<-- [start:CategoryIdentity]
        model: const CategoryModel(),
        title: 'Categories',
        icon: const BeakIconToken(OiIcons.folderTree),
        navigationGroup: 'Catalog',
        navigationRank: 5,
        // --8<-- [end:CategoryIdentity]
        // --8<-- [start:CategorySearchAndFilters]
        globalSearchSources: [
          CategoryModel.name,
          CategoryModel.description,
          CategoryModel.attributes.search(CategoryAttributeModel.name),
        ],
        filters: [CategoryModel.name.textFilter()],
        // --8<-- [end:CategorySearchAndFilters]
        screens: [
          // --8<-- [start:CategoryTableScreen]
          BeakTableScreen(
            fields: [CategoryModel.name, CategoryModel.description],
          ),
          // --8<-- [end:CategoryTableScreen]
          // --8<-- [start:CategoryFormScreen]
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: categoryForm(),
          ),
          // --8<-- [end:CategoryFormScreen]
        ],
      );
}
// --8<-- [end:CategoryResource]
