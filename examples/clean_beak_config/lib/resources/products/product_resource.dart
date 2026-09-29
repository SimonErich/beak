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
        // --8<-- [start:ProductResourceIdentity]
        model: const ProductModel(),
        title: 'Products',
        icon: const BeakIconToken(OiIcons.package),
        navigationGroup: 'Catalog',
        navigationRank: 3,
        // --8<-- [end:ProductResourceIdentity]
        // --8<-- [start:ProductDuplication]
        duplication: BeakDuplicationSpec(
          relations: [ProductModel.attributes, ProductModel.variants],
          reset: [ProductModel.sku, ProductVariantModel.stock],
        ),
        // --8<-- [end:ProductDuplication]
        // --8<-- [start:ProductBulkActions]
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
        // --8<-- [end:ProductBulkActions]
        // --8<-- [start:listProductSearch]
        globalSearchSources: [
          // --8<-- [start:ProductSearchOwnFields]
          ProductModel.name,
          ProductModel.sku,
          ProductModel.description,
          // --8<-- [end:ProductSearchOwnFields]
          ProductModel.images.search(ProductImageModel.caption),
          // --8<-- [start:ProductSearchCategory]
          ProductModel.category.name,
          // --8<-- [end:ProductSearchCategory]
          ProductModel.attributes.search(ProductAttributeModel.value),
          ProductModel.variants.search(ProductVariantModel.sku),
        ],
        // --8<-- [end:listProductSearch]
        // --8<-- [start:listProductFilters]
        filters: [
          ProductModel.category.relationFilter(),
          ProductModel.active.boolFilter(label: 'Available'),
          ProductModel.price.rangeFilter(label: 'Net price'),
        ],
        // --8<-- [end:listProductFilters]
        // --8<-- [start:ProductScreens]
        screens: [
          // --8<-- [start:listProductFields]
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
          // --8<-- [end:listProductFields]
          // --8<-- [start:ProductFormScreen]
          BeakFormScreen(
            // --8<-- [start:ProductFormLayout]
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: productForm(),
            // --8<-- [end:ProductFormLayout]
            drafts: shopDrafts('product'),
            reviewBeforeSave: true,
          ),
          // --8<-- [end:ProductFormScreen]
        ],
        // --8<-- [end:ProductScreens]
      );
}
