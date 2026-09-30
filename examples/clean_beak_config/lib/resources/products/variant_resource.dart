import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/product_variant.dart';
import 'models/variant_attribute.dart';
import 'screens/variant_form.dart';

/// A cross-product inventory view with the same reusable variant form.
final class VariantResource extends BeakResource {
  /// Creates the variants section.
  VariantResource()
    : super(
        model: const ProductVariantModel(),
        title: 'Variants',
        icon: const BeakIconToken(OiIcons.layers),
        navigationGroup: 'Catalog',
        navigationRank: 4,
        globalSearchSources: [
          ProductVariantModel.name,
          ProductVariantModel.sku,
          ProductVariantModel.product.name,
          ProductVariantModel.attributes.search(VariantAttributeModel.value),
        ],
        filters: [
          ProductVariantModel.product.relationFilter(),
          ProductVariantModel.active.boolFilter(label: 'Available'),
          ProductVariantModel.stock.numberRangeFilter(),
        ],
        screens: [
          BeakTableScreen(
            fields: [
              ProductVariantModel.name,
              ProductVariantModel.sku,
              ProductVariantModel.product.name.formatted(
                BeakValueFormat.text,
                label: 'Product',
              ),
              ProductVariantModel.price,
              ProductVariantModel.stock,
              ProductVariantModel.active,
            ],
          ),
          BeakFormScreen(
            roles: const {
              BeakScreenRole.read,
              BeakScreenRole.create,
              BeakScreenRole.edit,
            },
            layout: variantForm(),
          ),
        ],
      );
}
