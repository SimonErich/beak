# Shaping the panel

> Arrange resources, forms and custom content without rebuilding data plumbing.

Keep navigation and search in resource definitions. Keep the input arrangement in screen files. Register those resources and any custom pages in the panel.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import '../../shop_drafts.dart';
import 'models/product.dart';
import 'models/product_attribute.dart';
import 'models/product_image.dart';
import 'models/product_variant.dart';
import 'screens/product_form.dart';

/// Catalog management with nested specifications and variants.
final class ProductResource extends BeakResource {
  /// Creates the products section.
  ProductResource()
    : super(
        model: const ProductModel(),
        title: 'Products',
        icon: const BeakIconToken(OiIcons.package),
        navigationGroup: 'Catalog',
        navigationRank: 3,
        duplication: BeakDuplicationSpec(
          relations: [ProductModel.attributes, ProductModel.variants],
          reset: [ProductModel.sku, ProductVariantModel.stock],
        ),
        bulkActions: [
          BeakBulkAction.edit(
            key: 'activate-products',
            label: 'Make available',
            changes: [BeakFieldChange(ProductModel.active, true)],
          ),
          BeakBulkAction.edit(
            key: 'deactivate-products',
            label: 'Stop selling',
            changes: [BeakFieldChange(ProductModel.active, false)],
          ),
        ],
        globalSearchSources: [
          ProductModel.name,
          ProductModel.sku,
          ProductModel.description,
          ProductModel.images.search(ProductImageModel.caption),
          ProductModel.category.name,
          ProductModel.attributes.search(ProductAttributeModel.value),
          ProductModel.variants.search(ProductVariantModel.sku),
        ],
        filters: [
          ProductModel.category.relationFilter(),
          ProductModel.active.boolFilter(label: 'Available'),
          ProductModel.price.numberRangeFilter(label: 'Net price'),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              ProductModel.name,
              ProductModel.sku,
              ProductModel.category.name.formatted(
                BeakValueFormat.text,
                label: 'Category',
              ),
              ProductModel.price,
              ProductModel.active,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: productForm(),
            drafts: shopDrafts('product'),
            reviewBeforeSave: true,
          ),
        ],
      );
}
```

## Forms and tables

Generated fields provide input, formatting and filter helpers. Use cards, columns, sections and tabs to group related work. Wizard steps share the same draft runtime as ordinary forms; changing presentation does not change persistence.

`BeakFormSections` projects reusable sections into tabs, a plain layout or wizard steps. Group conditions can disable a complete section. Read mode displays values in the same structure.

## Custom content

The shop overview and Operations page combine live data blocks with custom widgets. `BeakScreen` supplies standalone pages; `BeakCustomResourceScreen` replaces selected resource routes. `BeakWidgetBlock` embeds a widget inside a block layout.

Custom widgets obtain the active panel's services through `beakDependencies(context)`. Reuse its repository, formatting and mutation notifications so custom content stays consistent with generated screens. Ordinary forms need no such access.

## Search and filtering

A resource declares global search sources and table filters with typed fields. Related paths request the necessary joins or loads. Standard controls expose loading, errors and retry while queries run.

## Continue reading

- [Testing and shipping](06-auth-tests-and-shipping.md)
- [Custom screens](../panel/custom-screens.md)
