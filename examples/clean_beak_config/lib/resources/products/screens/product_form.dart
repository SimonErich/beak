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
                // --8<-- [start:ProductDetailsCard]
                BeakCard(
                  title: 'Product details',
                  children: [
                    ProductModel.name.inputText(),
                    ProductModel.sku.inputText(label: 'Base SKU'),
                    ProductModel.description.inputText(),
                  ],
                ),
                // --8<-- [end:ProductDetailsCard]
                BeakCard(
                  title: 'Organization and pricing',
                  children: [
                    // --8<-- [start:productCategoryPicker]
                    ProductModel.category.inputCombobox(
                      exclusive: false,
                      createForm: categoryForm(includeAttributes: false),
                      description:
                          'Configure category attributes in Categories after saving.',
                    ),
                    // --8<-- [end:productCategoryPicker]
                    // --8<-- [start:ProductPriceInput]
                    ProductModel.price.inputCurrency(
                      label: 'Net catalog price',
                    ),
                    // --8<-- [end:ProductPriceInput]
                    ProductModel.taxRate.inputCombobox(
                      label: 'Default tax rate',
                    ),
                    // --8<-- [start:ProductActiveInput]
                    ProductModel.active.inputToggle(label: 'For sale'),
                    // --8<-- [end:ProductActiveInput]
                  ],
                ),
              ],
            ),
          ],
        ),
        BeakTab(
          title: 'Images',
          children: [
            // --8<-- [start:productGallery]
            ProductModel.images.galleryForm(
              image: ProductImageModel.image,
              caption: ProductImageModel.caption,
              position: ProductImageModel.position,
              label: 'Product gallery',
            ),
            // --8<-- [end:productGallery]
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
                // --8<-- [start:productAttributesTable]
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
                // --8<-- [end:productAttributesTable]
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
                // --8<-- [start:variantBuilderWidget]
                BeakFormWidget(
                  showOnRead: false,
                  builder: (context, draft) => ShopVariantBuilder(draft: draft),
                ),
                // --8<-- [end:variantBuilderWidget]
                // --8<-- [start:productVariantsTable]
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
                // --8<-- [end:productVariantsTable]
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
