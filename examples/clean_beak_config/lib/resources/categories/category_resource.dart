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
