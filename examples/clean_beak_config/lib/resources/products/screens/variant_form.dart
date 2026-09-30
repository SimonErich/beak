import 'package:beak/panel.dart';
import '../models/product_variant.dart';
import '../models/variant_attribute.dart';

/// Reused in the variant resource and inside a product's staged variant rows.
BeakFormLayout variantForm({bool includeProduct = true}) => BeakFormLayout(
  children: [
    if (includeProduct) ProductVariantModel.product.inputCombobox(),
    BeakColumns(
      children: [
        BeakCard(
          title: 'Variant identity',
          children: [
            ProductVariantModel.name.inputText(
              description:
                  'A choice customers recognize, such as 1 kg · whole bean.',
            ),
            ProductVariantModel.sku.inputText(label: 'SKU'),
          ],
        ),
        BeakCard(
          title: 'Price and availability',
          children: [
            ProductVariantModel.price.inputCurrency(label: 'Net unit price'),
            ProductVariantModel.stock.inputNumber(label: 'Available units'),
            ProductVariantModel.active.inputToggle(label: 'For sale'),
          ],
        ),
      ],
    ),
    variantAttributes(),
  ],
);

/// Variant characteristics are owned drafts saved with their parent.
BeakRelationTable variantAttributes() =>
    ProductVariantModel.attributes.tableForm(
      label: 'Variant attributes',
      removeBehavior: BeakRemoveBehavior.deleteOwned,
      children: [
        VariantAttributeModel.name.inputText(label: 'Attribute'),
        VariantAttributeModel.value.inputText(label: 'Value'),
      ],
    );
