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
          ProductModel.price.rangeFilter(label: 'Net price'),
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
