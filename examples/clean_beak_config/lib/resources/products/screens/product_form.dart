import 'package:beak/panel.dart';
import '../../categories/models/category_attribute.dart';
import '../../../domain/shop_attributes.dart';
import 'variant_builder.dart';
import '../../categories/screens/category_form.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../models/product_attribute.dart';
import '../models/product_variant.dart';
import 'variant_form.dart';

/// Shared catalog layout: core data, specifications and sellable variants.
BeakFormLayout productForm() => BeakFormLayout(
  children: [
    BeakTabs(
      tabs: [
        BeakTab(
          title: 'Overview',
          children: [
            BeakColumns(
              children: [
                BeakCard(
                  title: 'Product details',
                  children: [
                    ProductModel.name.inputText(),
                    ProductModel.sku.inputText(label: 'Base SKU'),
                    ProductModel.description.inputText(),
                  ],
                ),
                BeakCard(
                  title: 'Organization and pricing',
                  children: [
                    ProductModel.category.inputCombobox(
                      exclusive: false,
                      createForm: categoryForm(includeAttributes: false),
                      description:
                          'Configure category attributes in Categories after saving.',
                    ),
                    ProductModel.price.inputCurrency(
                      label: 'Net catalog price',
                    ),
                    ProductModel.taxRate.inputCombobox(
                      label: 'Default tax rate',
                    ),
                    ProductModel.active.inputToggle(label: 'For sale'),
                  ],
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Images',
          children: [
            ProductModel.images.galleryForm(
              image: ProductImageModel.image,
              caption: ProductImageModel.caption,
              position: ProductImageModel.position,
              label: 'Product gallery',
            ),
          ],
        ),
        BeakTab(
          title: 'Specifications',
          children: [
            BeakSection(
              title: 'Product attributes',
              description:
                  'Use a definition from the selected category, or add a custom specification.',
              children: [
                ProductModel.attributes.tableForm(
                  label: 'Specifications',
                  removeBehavior: BeakRemoveBehavior.deleteOwned,
                  children: [
                    ProductAttributeModel.definition.inputCombobox(
                      label: 'Category attribute',
                      enabledIf: (state) =>
                          state.parent?.asProduct.categoryId != null,
                      options: (state) => CategoryAttributeModel.options(
                        filter: CategoryAttributeModel.categoryId.eq(
                          state.parent?.asProduct.categoryId,
                        ),
                      ),
                    ),
                    ProductAttributeModel.name.inputText(
                      label: 'Attribute name',
                      derive: (state) =>
                          state.asProductAttribute.definition?.name ??
                          ProductAttributeModel.name.readFrom(
                            state.draft.snapshot,
                          ),
                    ),
                    ProductAttributeModel.value.inputAttribute(
                      label: 'Value',
                      definition: (state) => switch (state.read(
                        ProductAttributeModel.definition,
                      )) {
                        final BeakRecord record => shopAttributeDefinition(
                          record,
                        ),
                        null => null,
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Variants',
          children: [
            BeakSection(
              title: 'Sellable choices',
              description:
                  'Each variant has its own SKU, price and stock. Open additional details to configure its attributes.',
              children: [
                BeakFormWidget(
                  showOnRead: false,
                  builder: (context, draft) => ShopVariantBuilder(draft: draft),
                ),
                ProductModel.variants.tableForm(
                  label: 'Variants',
                  removeBehavior: BeakRemoveBehavior.deleteOwned,
                  children: [
                    ProductVariantModel.name.inputText(),
                    ProductVariantModel.sku.inputText(label: 'SKU'),
                    ProductVariantModel.price.inputCurrency(),
                    ProductVariantModel.stock.inputNumber(),
                  ],
                  advancedForm: BeakFormLayout(
                    children: [
                      ProductVariantModel.active.inputToggle(label: 'For sale'),
                      variantAttributes(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
